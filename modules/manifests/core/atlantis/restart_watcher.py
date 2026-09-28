#!/usr/bin/env python3
"""Restart stale Atlantis pods only after every local operation has finished."""

from __future__ import annotations

import json
import logging
import os
import ssl
import time
from urllib.parse import quote
from urllib.request import Request, urlopen


LOG = logging.getLogger("atlantis-restart-watcher")
POD_NAME = os.getenv("POD_NAME", "")
POD_NAMESPACE = os.getenv("POD_NAMESPACE", "")
ATLANTIS_STATUS_URL = os.getenv("ATLANTIS_STATUS_URL", "http://127.0.0.1:4141/status")
POLL_INTERVAL_SECONDS = max(1, int(os.getenv("POLL_INTERVAL_SECONDS", "10")))
IDLE_CONFIRMATIONS = max(1, int(os.getenv("IDLE_CONFIRMATIONS", "3")))
SERVICE_ACCOUNT_DIR = "/var/run/secrets/kubernetes.io/serviceaccount"


def kubernetes_client() -> tuple[str, str, ssl.SSLContext]:
    host = os.environ["KUBERNETES_SERVICE_HOST"]
    port = os.getenv("KUBERNETES_SERVICE_PORT_HTTPS") or os.getenv(
        "KUBERNETES_SERVICE_PORT", "443"
    )
    token_path = os.path.join(SERVICE_ACCOUNT_DIR, "token")
    ca_path = os.path.join(SERVICE_ACCOUNT_DIR, "ca.crt")
    with open(token_path, encoding="utf-8") as token_file:
        token = token_file.read().strip()
    context = ssl.create_default_context(cafile=ca_path)
    return f"https://{host}:{port}", token, context


def api_request(
    api_server: str,
    token: str,
    context: ssl.SSLContext,
    path: str,
    method: str = "GET",
    body: dict[str, object] | None = None,
) -> dict[str, object]:
    data = None if body is None else json.dumps(body).encode("utf-8")
    request = Request(
        f"{api_server}{path}",
        data=data,
        headers={
            "Accept": "application/json",
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method=method,
    )
    with urlopen(request, context=context, timeout=8) as response:
        payload = response.read()
    return json.loads(payload) if payload else {}


def get_atlantis_status() -> dict[str, object]:
    request = Request(ATLANTIS_STATUS_URL, headers={"Accept": "application/json"})
    with urlopen(request, timeout=5) as response:
        payload = response.read()
    return json.loads(payload)


def pod_api_path() -> str:
    namespace = quote(POD_NAMESPACE, safe="")
    pod_name = quote(POD_NAME, safe="")
    return f"/api/v1/namespaces/{namespace}/pods/{pod_name}"


def statefulset_api_path(statefulset_name: str) -> str:
    namespace = quote(POD_NAMESPACE, safe="")
    statefulset_name = quote(statefulset_name, safe="")
    return f"/apis/apps/v1/namespaces/{namespace}/statefulsets/{statefulset_name}"


def owning_statefulset_name(pod: dict[str, object]) -> str:
    owners = pod.get("metadata", {}).get("ownerReferences", [])
    for owner in owners:
        if owner.get("kind") == "StatefulSet" and owner.get("name"):
            return owner["name"]
    raise ValueError(f"Pod {POD_NAMESPACE}/{POD_NAME} has no StatefulSet owner")


def statefulset_is_observed(statefulset: dict[str, object]) -> bool:
    metadata = statefulset.get("metadata", {})
    status = statefulset.get("status", {})
    generation = metadata.get("generation", 0)
    observed_generation = status.get("observedGeneration", 0)
    return observed_generation >= generation


def in_progress_operations(status: dict[str, object]) -> int:
    count = status.get("in_progress_operations")
    if type(count) is not int or count < 0:
        raise ValueError("Atlantis /status returned an invalid operation count")
    return count


def has_pending_template(
    statefulset: dict[str, object], pod: dict[str, object]
) -> tuple[bool, str | None]:
    spec = statefulset.get("spec", {})
    strategy = spec.get("updateStrategy", {}).get("type", "RollingUpdate")
    replicas = spec.get("replicas", 1)
    if (
        strategy != "OnDelete"
        or replicas != 1
        or not statefulset_is_observed(statefulset)
    ):
        return False, None

    desired_revision = statefulset.get("status", {}).get("updateRevision")
    pod_revision = (
        pod.get("metadata", {}).get("labels", {}).get("controller-revision-hash")
    )
    if not desired_revision or not pod_revision or desired_revision == pod_revision:
        return False, None
    return True, desired_revision


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(name)s: %(message)s",
    )
    if not POD_NAME or not POD_NAMESPACE:
        raise SystemExit("POD_NAME and POD_NAMESPACE are required")

    api_server, token, context = kubernetes_client()
    pod_path = pod_api_path()
    statefulset_name = ""
    statefulset_path: str | None = None
    pending_revision: str | None = None
    idle_samples = 0

    while True:
        try:
            pod = api_request(api_server, token, context, pod_path)
            if pod.get("metadata", {}).get("deletionTimestamp"):
                LOG.info("Pod %s is already terminating; exiting", POD_NAME)
                return

            if not statefulset_name:
                statefulset_name = owning_statefulset_name(pod)
                statefulset_path = statefulset_api_path(statefulset_name)
                LOG.info(
                    "Watching StatefulSet %s/%s for a new pod revision; waiting for "
                    "all Atlantis operations to finish",
                    POD_NAMESPACE,
                    statefulset_name,
                )
            assert statefulset_path is not None
            statefulset = api_request(api_server, token, context, statefulset_path)
            spec = statefulset.get("spec", {})
            strategy = spec.get("updateStrategy", {}).get("type", "RollingUpdate")
            replicas = spec.get("replicas", 1)
            if strategy != "OnDelete":
                LOG.warning(
                    "StatefulSet strategy is %s, not OnDelete; watcher will not delete the pod",
                    strategy,
                )
                pending_revision = None
                idle_samples = 0
            elif replicas != 1:
                LOG.error(
                    "This watcher is configured for one replica; found %s replicas and will not delete any pod",
                    replicas,
                )
                pending_revision = None
                idle_samples = 0
            else:
                pending, desired_revision = has_pending_template(statefulset, pod)
                if not pending:
                    pending_revision = None
                    idle_samples = 0
                else:
                    assert desired_revision is not None
                    if desired_revision != pending_revision:
                        pending_revision = desired_revision
                        idle_samples = 0
                        LOG.info(
                            "New pod template %s is pending; waiting for Atlantis to become idle",
                            desired_revision,
                        )

                    atlantis_status = get_atlantis_status()
                    if atlantis_status.get("shutting_down"):
                        LOG.info(
                            "Atlantis is already draining; waiting for pod replacement"
                        )
                        idle_samples = 0
                    else:
                        in_progress = in_progress_operations(atlantis_status)
                        if in_progress:
                            LOG.info(
                                "Waiting for %d in-progress Atlantis operation(s)",
                                in_progress,
                            )
                            idle_samples = 0
                        else:
                            idle_samples += 1
                            LOG.info(
                                "Atlantis is idle (%d/%d consecutive checks)",
                                idle_samples,
                                IDLE_CONFIRMATIONS,
                            )

                            if idle_samples >= IDLE_CONFIRMATIONS:
                                # Re-read all three states immediately before deletion. If a new
                                # operation races this final check, Atlantis' SIGTERM drainer
                                # waits for it, subject to the pod's termination grace period.
                                latest_statefulset = api_request(
                                    api_server, token, context, statefulset_path
                                )
                                latest_pod = api_request(
                                    api_server, token, context, pod_path
                                )
                                latest_pending, latest_revision = has_pending_template(
                                    latest_statefulset, latest_pod
                                )
                                latest_status = get_atlantis_status()
                                latest_count = in_progress_operations(latest_status)
                                if (
                                    latest_pending
                                    and latest_revision == pending_revision
                                    and not latest_status.get("shutting_down")
                                    and latest_count == 0
                                    and not latest_pod.get("metadata", {}).get(
                                        "deletionTimestamp"
                                    )
                                ):
                                    LOG.info(
                                        "All Atlantis operations are complete; deleting "
                                        "stale pod %s so the StatefulSet recreates it "
                                        "with revision %s",
                                        POD_NAME,
                                        latest_revision,
                                    )
                                    api_request(
                                        api_server,
                                        token,
                                        context,
                                        pod_path,
                                        method="DELETE",
                                        body={
                                            "apiVersion": "v1",
                                            "kind": "DeleteOptions",
                                        },
                                    )
                                    # Keep the sidecar alive until Kubernetes terminates the pod.
                                    while True:
                                        time.sleep(3600)
                                else:
                                    LOG.info(
                                        "State changed during the final check; continuing to watch"
                                    )
                                    idle_samples = 0

        except Exception as error:
            # Fail closed: never restart when any check is uncertain.
            LOG.warning("Watcher check failed safely; it will retry: %s", error)
            idle_samples = 0

        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
