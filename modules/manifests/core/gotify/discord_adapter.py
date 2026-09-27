#!/usr/bin/env python3
"""Small Alertmanager-to-Discord bridge with per-severity embed colors."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

COLORS = {
    "critical": 0xED4245,
    "warning": 0xF1C40F,
    "info": 0x3498DB,
    "information": 0x3498DB,
    "debug": 0x95A5A6,
    "none": 0x95A5A6,
}
RESOLVED_COLOR = 0x2ECC71
SEVERITY_EMOJI = {
    "critical": "🔴",
    "warning": "🟠",
    "info": "🔵",
    "information": "🔵",
    "debug": "⚪",
    "none": "⚪",
}
MAX_BODY = 1_048_576
MAX_DESCRIPTION = 3_800
MAX_DISCORD_URL = 2_048
MAX_EMBEDS = 10


def _format_labels(labels):
    rows = [(str(key), str(value).replace("\n", " ").replace("|", "\\|")) for key, value in sorted((labels or {}).items())]
    width = max([len("label"), *(len(key) for key, _ in rows)])
    lines = [f"{'label':<{width}} | value", "-" * width + "-+-" + "-" * max(5, max((len(value) for _, value in rows), default=5))]
    lines.extend(f"{key:<{width}} | {value}" for key, value in rows)
    return "\n".join(lines)


def build_embeds(payload):
    alerts = payload.get("alerts") or []
    if not alerts:
        return []
    group_labels = payload.get("groupLabels") or {}
    first_labels = alerts[0].get("labels") or {}
    severity = str(group_labels.get("severity") or first_labels.get("severity") or "unknown").lower()
    severity_color = COLORS.get(severity, 0x7F8C8D)
    fallback_status = str(payload.get("status") or "firing").lower()
    statuses = {str(alert.get("status") or fallback_status).lower() for alert in alerts}
    severity_emoji = SEVERITY_EMOJI.get(severity, "⚪")
    if statuses == {"resolved"}:
        status = "Resolved"
        title_prefix = "✅"
    else:
        status = "Firing"
        title_prefix = severity_emoji
    title = f"{title_prefix} {status}: {len(alerts)} alert(s)"
    color = RESOLVED_COLOR if status == "Resolved" else severity_color

    blocks = []
    for alert in alerts:
        labels = alert.get("labels") or {}
        annotations = alert.get("annotations") or {}
        alert_name = str(labels.get("alertname") or group_labels.get("alertname") or "Alert")
        alert_severity = str(labels.get("severity") or group_labels.get("severity") or "unknown").upper()
        description = str(annotations.get("description") or annotations.get("summary") or "No description provided.").strip()
        description = description.replace("```", "'''")
        subject = "/".join(str(labels[key]) for key in ("pod", "container") if labels.get(key))
        if not subject:
            subject = str(labels.get("instance") or "")
        namespace = str(labels.get("namespace") or "")
        location = f"on {subject} ({namespace})" if subject and namespace else (f"on {subject}" if subject else (f"on ({namespace})" if namespace else ""))
        lines = [
            f"**Alert:** {alert_name}",
            f"**Severity:** {SEVERITY_EMOJI.get(alert_severity.lower(), '⚪')} {alert_severity}",
            f"**Description:** {description}",
        ]
        if location and location not in description:
            lines.append(location)
        lines.extend(["", "**Labels:**", "```text", _format_labels(labels), "```"])
        blocks.append("\n".join(lines))

    descriptions = []
    current = ""
    for block in blocks:
        if len(block) > MAX_DESCRIPTION:
            block = block[:MAX_DESCRIPTION - 3] + "..."
        addition = ("\n\n" if current else "") + block
        if current and len(current) + len(addition) > MAX_DESCRIPTION:
            descriptions.append(current)
            current = block
        else:
            current += addition
    if current:
        descriptions.append(current)

    total = len(descriptions)
    embeds = []
    for index, description in enumerate(descriptions, 1):
        page = f" ({index}/{total})" if total > 1 else ""
        embed = {"title": (title + page)[:256], "description": description, "color": color}
        generator = next((str(alert.get("generatorURL")).strip() for alert in alerts if alert.get("generatorURL")), None)
        if generator:
            try:
                parsed_generator = urlsplit(generator)
                valid_generator = (
                    parsed_generator.scheme in {"http", "https"}
                    and bool(parsed_generator.netloc)
                    and len(generator) <= MAX_DISCORD_URL
                )
            except ValueError:
                valid_generator = False
            if valid_generator:
                embed["url"] = generator
            else:
                print("generator URL omitted: invalid or exceeds Discord's 2048-character embed URL limit", flush=True)
        timestamp_key = "endsAt" if status == "Resolved" else "startsAt"
        timestamp = next((alert.get(timestamp_key) for alert in alerts if alert.get(timestamp_key)), None)
        if timestamp:
            embed["timestamp"] = timestamp
        embeds.append(embed)
    return embeds


def _embed_text_chars(embed):
    total = len(str(embed.get("title", ""))) + len(str(embed.get("description", "")))
    total += len(str((embed.get("footer") or {}).get("text", "")))
    total += len(str((embed.get("author") or {}).get("name", "")))
    for field in embed.get("fields") or []:
        total += len(str(field.get("name", ""))) + len(str(field.get("value", "")))
    return total


def _chunk_embeds(embeds):
    batches = []
    current = []
    current_chars = 0
    for embed in embeds:
        embed_chars = _embed_text_chars(embed)
        if current and (len(current) >= MAX_EMBEDS or current_chars + embed_chars > 6_000):
            batches.append(current)
            current = []
            current_chars = 0
        current.append(embed)
        current_chars += embed_chars
    if current:
        batches.append(current)
    return batches


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Do not log request bodies or the Discord webhook URL.
        print("alertmanager-discord-adapter: " + (fmt % args), flush=True)

    def _reply(self, code, body=b"", content_type="text/plain"):
        self.send_response(code)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if body:
            self.wfile.write(body)

    def do_GET(self):
        if self.path == "/healthz":
            self._reply(200, b"ok")
        else:
            self._reply(404, b"not found")

    def do_POST(self):
        if self.path != "/alertmanager":
            self._reply(404, b"not found")
            return
        try:
            size = int(self.headers.get("Content-Length", "0"))
            if size <= 0 or size > MAX_BODY:
                self._reply(413, b"invalid request size")
                return
            payload = json.loads(self.rfile.read(size))
            embeds = build_embeds(payload)
            if not embeds:
                self._reply(200, b"no alerts")
                return
            webhook = os.environ["DISCORD_WEBHOOK_URL"]
            for embed_batch in _chunk_embeds(embeds):
                body = json.dumps({
                    # "username": "Prometheus Alertmanager",
                    "allowed_mentions": {"parse": []},
                    "embeds": embed_batch,
                }).encode()
                request = Request(webhook, data=body, headers={"Content-Type": "application/json", "User-Agent": "AlertmanagerDiscordAdapter/1.0"}, method="POST")
                with urlopen(request, timeout=10) as response:
                    if response.status >= 300:
                        raise RuntimeError(f"Discord returned HTTP {response.status}")
            self._reply(200, b"sent")
        except (ValueError, KeyError, json.JSONDecodeError) as error:
            print(f"invalid Alertmanager payload: {error}", flush=True)
            self._reply(400, b"invalid payload")
        except HTTPError as error:
            print(f"Discord delivery failed: HTTP {error.code}", flush=True)
            self._reply(502, b"delivery failed")
        except (URLError, TimeoutError, RuntimeError) as error:
            print(f"Discord delivery failed: {type(error).__name__}", flush=True)
            self._reply(502, b"delivery failed")
        except Exception as error:
            print(f"request failed: {type(error).__name__}", flush=True)
            self._reply(500, b"request failed")


if __name__ == "__main__":
    if not os.environ.get("DISCORD_WEBHOOK_URL"):
        raise SystemExit("DISCORD_WEBHOOK_URL is required")
    port = int(os.environ.get("PORT", "8080"))
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()
