# AGENTS.md — k8s.tf

Instructions for coding agents working in this repository. Read this before
changing anything; this cluster is production and serves real data.

## Project overview

End-to-end Kubernetes cluster IaC: **OpenTofu** modules orchestrated by
**Terragrunt** as a layered stack, running **Talos Linux** on **Hetzner Cloud**
(3 control planes + 3 workers, Helsinki/Nuremberg/Falkenstein, dual-stack),
with **Tailscale** node networking, **Cilium** CNI, and **Cloudflare** DNS.
All configuration lives in `prod.values.hcl` (values) and
`prod.secrets.hcl` (SOPS-encrypted secrets).

```
terragrunt.stack.hcl           # root stack: infra + manifests wiring
prod.values.hcl                # single source of truth (cluster, nodes, modules)
prod.secrets.hcl               # SOPS-encrypted secrets (never decrypt casually)
secrets.hcl.example            # secrets template; update when a module gains a secret
.sops.yaml                     # age keys / creation rules
Makefile                       # generate / plan / apply / destroy / encrypt / lint
modules/common.hcl             # backend, state encryption, mock outputs, mock_infra
modules/infra/                 # talos (pre/post, templates/*.tmpl), hetzner, tailscale, cloudflare
modules/manifests/core/        # cluster services (loki, kube-prometheus-stack, falco, ...)
modules/manifests/apps/        # end-user apps (+ template/ scaffold)
packer/                        # Talos image build for Hetzner (own SOPS secret file)
.terragrunt-stack/             # GENERATED units — gitignored, never edit by hand
.terraform/<env>/              # LOCAL STATE (default backend) — gitignored, never delete
```

State backend is selected by `TF_BACKEND_TYPE` (`local` default, or `s3`; see
`modules/common.hcl`). With the local backend, state lives in
`.terraform/<env>/modules/<unit>/terraform.tfstate`. `make clean` removes both
`.terragrunt-stack/` and `.terraform/` (it asks for confirmation) — never run it
without the owner's approval. When making scratch copies for offline tests,
exclude `.terraform/`, `.terragrunt-stack/` and `.git`, and delete the copy afterwards.
Note: `modules/*/.terragrunt-stack` dirs can also exist from earlier runs.

## Environment

- Development happens on NixOS. If a tool is missing from `$PATH`, prefer the
  repo's expected versions or `nix shell nixpkgs#<package> -c <cmd>`; do not
  install ad hoc packages.
- Tools used: `tofu` (OpenTofu), `terragrunt`, `helm`, `kubectl`, `talosctl`,
  `sops`, `jq`, `packer` (image builds only), `lefthook` (git hooks).
- `terragrunt hclfmt` flag names vary by build; validated form is
  `terragrunt hcl format --check <file-or-dir>`.

## Commands

All mutating targets decrypt secrets first (`_with_secrets`), so the secrets
file (default `<ENV>.secrets.hcl`, i.e. `prod.secrets.hcl`) must exist.

```sh
make generate                        # regenerate .terragrunt-stack/ (needs decrypted secrets)
make plan     ENV=prod               # plan all units (infra + manifests, if kubeconfig reachable)
make apply    ENV=prod               # apply infra then manifests
make infra-plan | infra-apply | infra-destroy
make manifests-plan | manifests-apply | manifests-destroy
make lint                            # terragrunt hcl fmt + tofu fmt -recursive
make decrypt | encrypt               # SOPS in place (needs SOPS_AGE_KEY_FILE)
make build                           # Packer Talos image (separate packer/<env>.secret.hcl)
```

Variables:

- `ENV=prod|dev` — selects `<ENV>.values.hcl` / `<ENV>.secrets.hcl` (via `STACK_ENV`).
- `TARGET=infra|apps` — narrows manifest targets to `core` / `apps`.
- `TG_FILTER=<unit>` — run one module only, e.g. `make manifests-plan TG_FILTER=core/loki`.
- `SECRETS=/path/to/secrets.hcl` — override the secrets file.
- **Mock mode**: if the values file lacks an `infra = {` block, the stack falls
  back to `modules/common.hcl` `mock_infra` for plan-only work. Apply/destroy
  with mock values is blocked by `_check_values`. Do not work around it.

Manifests targets require a valid kubeconfig and a reachable API server.

## Safety rules

- **Never run** `make apply`, `make *-destroy`, terraform/tofu `apply`,
  `destroy`, or any live cluster write (kubectl/talosctl mutating commands)
  without explicit user approval. Read-only `kubectl get/describe/logs` is acceptable.
- **Never test with raw `terraform plan` / `tofu plan`** (or `terragrunt plan`)
  in a module or generated unit: it bypasses the stack wiring, secrets loading
  and mock-mode guards. Plan only through the Makefile (`make plan`,
  `make infra-plan`, `make manifests-plan [TARGET=...] [TG_FILTER=<unit>]`).
- **Secrets**: never decrypt, print, copy, or diffuse values from
  `prod.secrets.hcl`, `packer/prod.secret.hcl`, or `.envrc`. Template only
  placeholder values in `secrets.hcl.example`. lefthook's `check-sops` hook
  fails any commit touching `*secret*` files that are not SOPS-encrypted and
  are not `*.example` / `*/secret.tf`. Do not bypass it.
- SOPS edit loop is `make decrypt` -> edit -> `make encrypt`, which needs the
  age key (`SOPS_AGE_KEY_FILE`); you normally have no such key — leave real
  secrets edits to the owner.
- Do not stage/commit generated files (`.terragrunt-stack/`, `.terraform/`,
  lock plans), user data files (e.g. `.ci/public-domains.csv`), or anything you
  did not create.
- If a task needs push, live writes, or image rebuilds, stop and ask.

## Adding a core module

Follow an existing module (loki or descheduler are clean references):

1. Create `modules/manifests/core/<name>/` with `terragrunt.hcl`,
   `variables.tf`, `helm.tf`, `namespace.tf` (if the chart runs privileged),
   optional `prometheusrule.tf`, `secret.tf` (plus optional `outputs.tf`).
2. `terragrunt.hcl`: 99-char box header with module path + short description
   + `Config is provided from stack values.` + `Apply order: deps -> [unit]`;
   `include "common"` (exposed), `exclude { if = !try(values.enabled, false), actions = ["all"] }`,
   `generate "providers"` (`config_path = "~/.kube/config"`) and
   `generate "versions"` with the standard kubernetes/helm pins,
   `inputs = { enabled = try(values.enabled, false), config = ..., secrets = try(values.secrets, {}) }`.
   Both config styles exist: an explicit key list with `try()` defaults
   (descheduler, trivy) or `merge(try(values.config, {}), {...})` when keys are
   generated from dependencies (loki, falco). With an explicit list, keys not
   listed are silently dropped.
3. `variables.tf`: `enabled` + `config`/`secrets` objects; describe each key in
   the aligned header (`key         --- description`).
4. `helm.tf`: single `helm_release "this"`, `upgrade_install = true`, chart
   **version hardcoded** (Renovate's terraform manager tracks it), namespace
   from your own namespace resource; scalars in alphabetically sorted
   `set = [{ name, value }]` entries, structures in `values = [yamlencode({...})]`
   (values containing commas must go through `yamlencode`), no inline
   comments, `depends_on` the namespace resource.
5. Namespaces with privileged pods: label them
   `pod-security.kubernetes.io/{enforce,audit,warn} = "privileged"` (Talos
   default PSA is `enforce=baseline`, only `kube-system` exempt). Prefer
   setting container `resources` over exemptions.
6. The cluster-wide Kyverno `require-pod-resources` ValidatingPolicy (Deny)
   requires `requests.cpu`, `requests.memory`, `limits.memory` on every regular
   container. Render the chart and verify every regular container has them.
7. Dependencies: needing ServiceMonitor CRDs -> `dependency "../kube-prometheus-stack/pre"`
   with `skip_outputs = true`; needing the monitoring namespace -> `dependency "../kube-prometheus-stack"`
   with `mock_outputs = { namespace = "monitoring" }` and the shared
   `include.common.locals.mock_outputs_*` settings, then merge the namespace
   into `config`.
   **CRDs must exist at plan time.** `kubernetes_manifest` (and chart features
   such as ServiceMonitor/PrometheusRule/PodMonitor) need their CRD on the API
   server when the unit is *planned*, so the unit that installs the CRD must be
   in the consumer's dependency closure: monitoring CRDs ->
   `kube-prometheus-stack/pre`, `traefik.io` (Middleware, TraefikService) and
   the `nginx` IngressClass -> `core/traefik`, `longhorn.io` -> `core/longhorn`,
   `postgresql.cnpg.io` -> `core/cnpg`, MongoDB CRs ->
   `core/mongodb-community-operator`, Kyverno policies -> `core/kyverno`.
   Gateway API CRDs come from Talos boot (`modules/infra/talos`) and need no
   edge. Never create CRs in the same unit whose chart installs their CRDs;
   put them in a sub-unit (precedent: `kyverno/policies`,
   `kube-prometheus-stack/pre`). An existing cluster hides these bugs; check
   them with `terragrunt dag graph` in a scratch stack.
8. Wire the stack: add `unit "<name>"` in `modules/manifests/terragrunt.stack.hcl`
   (alphabetical), add the `config` block to `prod.values.hcl` under
   `manifests.core` (if it consumes secrets also add keys to
   `secrets.hcl.example` under `manifests.core.<name>`), and add the module
   name to the README layout tree / layer table / dependency graph.
9. Validate offline (see recipe below), then hand apply/plan commands to the
   owner.

When a CRD can't be in the dependency closure in time (e.g. its CRDs ship in
the same unit's chart), the repo pattern is `null_resource` + `kubectl apply`
(precedent: `cert-manager/wildcard.tf`, `cert-manager/issuer.tf`,
`tailscale-operator/subnetrouter.tf`, `apps/nightscout/db.tf`), never
`kubernetes_manifest`. Do NOT probe existence with `data "external"` or gate
the apply on an `exists` trigger: on replacement the destroy provisioner then
deletes the live object while the new instance skips `kubectl apply`. Instead:
always apply, add `lifecycle { create_before_destroy = true }`, stamp
`srv.mtaha.dev/tf-owner = <self.id>` with `kubectl annotate` after apply, and
let the destroy provisioner delete only when that annotation still equals
`${self.id}` (replacement applies first, so it can never gap the object).

## Adding an app

Applications live in `modules/manifests/apps/<name>` (see `apps/template/` for
the scaffold: namespace/deployment/service/pvc/db/httproute/secret files).
Apps get their own namespace, an `HTTPRoute` on the Traefik Gateway with the
ExtensionRef BasicAuth middleware pattern for protected endpoints, and follow
the same stack/value wiring as core modules under `manifests.apps`. The
CRD-at-plan-time rule (core step 7) applies too: an app creating a Traefik
`Middleware` needs `dependency "traefik"` (`../../core/traefik`), a CNPG
database needs `../../core/cnpg`.

## Talos / platform gotchas

- Talos is immutable: no `/etc/systemd`, no static pod manifests; containerd
  socket is `/run/containerd/containerd.sock`; `/etc` is read-only. Do not
  assume host paths from generic charts exist (`/var/lib/etcd` is
  control-plane-only; `/var/lib/kube-scheduler`, `/var/lib/kube-controller-manager`
  do not exist) — trim chart hostPath/volume lists to real Talos paths.
- The kernel forbids unsigned modules (`module.sig_enforce=1`): eBPF-only
  solutions (e.g. Falco `driver.kind: modern_ebpf`) are the only option.
- Falco's YAML-to-JSON decoder turns every empty YAML `[]`/`{}` inside a
  plugin `init_config` into `null` (bug in `yaml_helper.h`, unfixed upstream),
  so a `sockets = []` on a disabled container engine crashes the plugin at
  startup. Never write empty lists into values that feed plugin init_config;
  for the falco chart, disable engines with `{ enabled = false }` and let the
  chart defaults keep their socket lists (mounts are gated on `enabled`).
  Verify plugin init with `falco -c <rendered-falco.yaml> --plugin-info container`.
  Note: after changing helm values, the live release keeps the OLD values until
  the unit is applied again (`make manifests-apply TG_FILTER=core/<name>`); a
  mis-scheduled pod from the previous values keeps crashing until then.
- Control-plane nodes keep the default `NoSchedule` taint; DaemonSets or
  node-scanned jobs need explicit tolerations (repo convention:
  `{ operator = "Exists" }`). Longhorn runs **only on workers** (no role label
  exists to select workers), so any pod mounting a Longhorn PVC (e.g. the
  trivy built-in server) must NOT tolerate the control-plane taint — leave
  `tolerations` empty and let the taint keep it off the control planes.
- **Pin the Talos machine-config contract** (`talos_version`) — a provider/SDK
  bump switching the config contract is a migration, not an update (see RCA
  2026-10-20); reproducing infra issues with `talosctl gen config` +
  `talosctl validate --mode cloud` is safe and encouraged.
- Correct render of a pinned chart (e.g. `helm template <chart> --repo <url>
  --version <v>`) is the fastest way to catch Talos-incompatible hostPaths.

## Observability / alerting conventions

- Prometheus picks up **all** ServiceMonitors/PrometheusRules
  (`serviceMonitorSelectorNilUsesHelmValues = false`, no namespace selector).
- Grafana sidecar loads ConfigMaps labelled `grafana_dashboard = "1"` from all
  namespaces (NAMESPACE=ALL); a module can keep its dashboard ConfigMap in its
  own namespace (precedent: `trivy/dashboard.tf`; the falco chart installs its
  dashboard into the monitoring namespace).
- Grafana dashboard ownership must be unique per uid: the kps `default`
  file-provider persists gnetId downloads on the grafana PVC, so a chart that
  also creates a `grafana_dashboard = "1"` ConfigMap with the same uid (CNPG)
  puts provisioning into read-only mode and silently blocks all sidecar
  dashboards. Give every dashboard exactly one source.
- Alertmanager (v0.34): routes key off `severity` (`info|warning|critical`) and
  group on `alertname,namespace,severity`; an inhibit rule suppresses
  `info` alerts in the same `namespace` as a firing `warning` (alerts without a
  `namespace` label all count as one namespace). External alert
  sources (e.g. falcosidekick) must therefore set `alertname` and `namespace`
  labels and use the `/api/v2/alerts` endpoint.
- Prometheus volume sizing matters: a full TSDB disk is a dead end (alerts go
  blind because rule results are appended to the same WAL) — see RCA
  2026-10-06; keep `prometheus_retention_size` within the PVC.

## Offline validation recipe

Never plan/validate against the live cluster by accident. These steps never
run `plan`; when a real plan is needed, use the `make *-plan` targets only:

1. `tofu fmt -check -recursive <module>` and
   `terragrunt hcl format --check <file>`.
2. Render charts offline: `helm template <name> <chart-dir-or-repo-url> --version <v> -f <values.yaml>`
   — generate the values file from the module's `yamlencode`/`set` block
   (e.g. through `tofu console`) rather than hand-transcribing.
3. For `tofu validate` without cluster/state: copy the module to a temp dir
   (copy any `file()` support files), write a stub `versions.tf`, run
   `tofu init -backend=false -input=false && tofu validate -no-color`.
   Needing a namespace output from un-applied deps resolves thanks to the
   shared mock outputs (`namespace = "monitoring"`).
4. If stack wiring changed: generate the stack in a scratch copy (`STACK_ENV=prod terragrunt stack generate`), `terragrunt hcl validate`, optionally
   `terragrunt run -- validate` per unit. Use `TERRAGRUNT_SECRETS=secrets.hcl.example`
   for secret-shaped values; look at `secrets.hcl.example`, not real secrets.
5. `git diff --check` before finishing; also confirm no `.terraform/` or temp
   copies leaked into the repo.

Point `KUBECONFIG` at an empty path in scratch shells and set
`TERRAGRUNT_SECRETS` explicitly so nothing accidental resolves live.

## Renovate

- Managers: built-in `terraform` (tracks `helm_release` chart versions and
  provider pins in `terragrunt.hcl` generate blocks) plus a `custom.regex`
  manager over `prod.values.hcl` and `modules/**/*.tf` for `# renovate:
  datasource=<ds> depName=<dep>[ registryUrl=<url>] <var> = "<version>"`
  comment lines (the colon after `renovate` is required; the
  `# renovate = ...` line in `core/traefik/helm.tf` does not match and is inert).
- Groups: `core-infrastructure` (`modules/infra/**` + `prod.values.hcl`),
  `infra-manifests` (`modules/manifests/core/**`), `apps`. Helm minor/patch and
  Docker patch updates automerge. Updates for `apps/template/**` are
  disabled except terraform-provider blocks.

## Commits & PRs

- Conventional Commits with scopes matching the layout:
  `fix(manifests/core): ...`, `fix(infra/talos): ...`, `chore(deps): ...`.
  Renovate opens PRs from `mt190502/renovate/*` branches; history shows merge
  commits rather than squashes. Check `git log --oneline` and match style
  before committing.
- One logical topic per commit; never include unrelated user files.
- CODEOWNERS is `* @mt190502` — review happens with the owner; do not merge.
