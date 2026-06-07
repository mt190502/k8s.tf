# k8s.tf - Kubernetes Cluster IaC with OpenTofu/Terraform + Terragrunt

End-to-end Kubernetes infrastructure managed with **OpenTofu** modules and orchestrated
by **Terragrunt** as a layered stack and DAG. The cluster runs on **Talos Linux**
with **Hetzner Cloud** for compute, **Tailscale** for node-to-node networking,
**Cloudflare DNS** for domain management, and core cluster services including storage,
observability, and certificate management.

**Key Features (prod.values.hcl):**
- Multi-region Talos Kubernetes clusters with IPv4/IPv6 dual-stack networking
- Cilium CNI for pod networking (WireGuard optional, currently disabled)
- Traefik Gateway API for ingress with HTTPS/QUIC support
- Tailscale mesh for secure node-to-node communication (Kubespan disabled)
- Mixed architecture: ARM64 control planes, AMD64 workers
- SOPS + age encryption for sensitive configuration
- Terragrunt stack-based deployment with dependency management
- Centralized mock outputs for plan/destroy without applied state
- **Mock mode for testing** — plan infrastructure without real configuration

<br>

## Architecture Overview

```mermaid
graph TD
  domain["srv.mtaha.dev"]
  cloudflare["Cloudflare<br/>Round Robin"]
  domain --> cloudflare

  subgraph TALOS["Talos Kubernetes Cluster"]
    subgraph STORAGE_STACK["StorageClass Stack"]
      storage_s3["S3 CSI"]
      storage_longhorn["Longhorn"]
    end
    tailscale["Tailscale<br>(node-to-node)<br>(UDP/41641)"]
    subgraph NETWORK_STACK["Node Networking Stack"]
      route["HTTPRoute"]
      gateway["Gateway API"]
      gwprovider["Traefik Gateway"]
    end
    subgraph CORE["Core Services"]
      alloy["Grafana Alloy"]
      atlantis["Atlantis"]
      cert["Cert Manager"]
      descheduler["Descheduler"]
      dnsutils["DNS Utils"]
      loki["Loki"]
      monitoring["Kube Prometheus Stack"]
      mongo["MongoDB Operator"]
      pg["CloudNative-PG"]
      psmdb["PSMDB Operator"]
      reflector["Reflector"]
      testing["Testing"]
      tso["Tailscale Operator"]
      traefik["Traefik"]
    end
    subgraph APPS["Applications"]
      anki["Anki"]
      gotify["Gotify"]
      miniflux["Miniflux"]
      nightscout["Nightscout"]
      radicale["Radicale"]
      redmine["Redmine"]
      slimserve["Slimserve"]
      sync["Syncstorage-rs"]
      umami["Umami"]
    end

    subgraph CLUSTER1["Hetzner Cloud"]
      subgraph HEL1["🇫🇮 Helsinki"]
        m1a["m1 (CP/arm64)"]
        w1a["w1 (amd64)"]
      end

      subgraph NBG1["🇩🇪 Nuremberg"]
        m2a["m2 (CP/arm64)"]
        w2a["w2 (amd64)"]
      end

      subgraph FSN1["🇩🇪 Falkenstein"]
        m3a["m3 (CP/arm64)"]
        w3a["w3 (amd64)"]
      end
    end
  end

  cloudflare -->|:443| m1a
  cloudflare -->|:443| w1a
  cloudflare -->|:443| m2a
  cloudflare -->|:443| w2a
  cloudflare -->|:443| m3a
  cloudflare -->|:443| w3a

  route <--> gateway <--> gwprovider
  m1a <-.-> route
  w1a <-.-> route
  m2a <-.-> route
  w2a <-.-> route
  m3a <-.-> route
  w3a <-.-> route

  tailscale <-.-> m1a
  tailscale <-.-> w1a
  tailscale <-.-> m2a
  tailscale <-.-> w2a
  tailscale <-.-> m3a
  tailscale <-.-> w3a
  gwprovider <---> CORE
  CORE <---> STORAGE_STACK
  CORE --> APPS

  classDef infra fill:#0ea5e9,stroke:#0369a1,color:#fff;
  classDef network fill:#8b5cf6,stroke:#5b21b6,color:#fff;
  classDef core fill:#10b981,stroke:#065f46,color:#fff;
  classDef app fill:#f59e0b,stroke:#92400e,color:#fff;
  classDef storage fill:#6366f1,stroke:#4338ca,color:#fff;
  classDef node fill:#ef4444,stroke:#7f1d1d,color:#fff;

  class domain,cloudflare infra;
  class route,gateway,gwprovider,tailscale network;
  class atlantis,cert,monitoring,dnsutils,reflector,pg,psmdb,testing,tso,traefik,alloy,descheduler,loki,mongo core;
  class anki,miniflux,nightscout,radicale,redmine,umami,gotify,slimserve,sync app;
  class storage_s3,storage_longhorn storage;
  class m1a,w1a,m2a,w2a,m3a,w3a node;

  style TALOS fill:#111827,stroke:#374151,color:#fff
  style STORAGE_STACK fill:#1f2937,stroke:#6366f1,color:#fff
  style NETWORK_STACK fill:#1f2937,stroke:#8b5cf6,color:#fff
  style CORE fill:#1f2937,stroke:#10b981,color:#fff
  style APPS fill:#1f2937,stroke:#f59e0b,color:#fff
  style CLUSTER1 fill:#1f2937,stroke:#3b82f6,color:#fff
  style HEL1 fill:#020617,stroke:#3b82f6,color:#fff
  style NBG1 fill:#020617,stroke:#3b82f6,color:#fff
  style FSN1 fill:#020617,stroke:#3b82f6,color:#fff

  linkStyle default stroke:#fff,stroke-width:2px;
```

<br>

## Prerequisites


| Tool                  | Role                                               |
| --------------------- | -------------------------------------------------- |
| OpenTofu or Terraform | Provider and resource engine                       |
| Terragrunt            | Stack generation, `run --all`, DAG                 |
| `sops` + `age`        | Encryption for `secrets.hcl` / `packer/secret.hcl` |
| `kubectl`             | Cluster access before manifest plan/apply          |
| `jq`                  | SOPS status check during `make generate`           |
| Packer (optional)     | Talos image build for Hetzner                      |

<br>

## Quick Start

### 1. Secrets

```sh
cp secrets.hcl.example secrets.hcl
# Fill in your credentials (must be plain text before encryption) (https://github.com/FiloSottile/age)
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
make encrypt
```

To edit secrets later: `make decrypt` → edit → `make encrypt`.

### 2. Cluster Configuration

Update `infra` (cluster name, `cluster_url`, nodes, firewall, versions) and `apps`
blocks in `prod.values.hcl` for your environment.

> [!TIP]
> If `prod.values.hcl` is empty or missing the `infra` block, the stack runs in **mock mode**
> using default values from `modules/common.hcl`. This allows `make infra-plan` without real
> configuration. Apply/destroy operations are blocked in mock mode.

### 3. Generate Stack and Apply

Default environment is **prod** (`ENV=prod`). `make generate` requires `secrets.hcl`
to be **decrypted**.

```sh
# Apply entire stack (infrastructure then manifests)
make apply

# Or apply layers separately
make infra-apply
make manifests-apply
```

> [!NOTE]
> Manifest targets require a valid kubeconfig and reachable API server.

---

### Repository Architecture

All shared configuration lives under `locals` in `prod.values.hcl`. Sensitive values such as API tokens are stored in `secrets.hcl` and encrypted with **SOPS**.

| Layer              | Content                                                                                                                                                                                                                                                                                                                       |
|:------------------:|:-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| **Infrastructure** | Talos machine secrets, patch templates, Hetzner servers + firewall, Tailscale devices, Talos bootstrap, kubeconfig, Cloudflare DNS records                                                                                                                                                                                    |
| **Manifests**      | Longhorn, S3 CSI, Reflector, CloudNativePG, PSMDB Operator, MongoDB Community Operator, kube-prometheus-stack, Loki, Grafana Alloy, cert-manager, Descheduler, Atlantis, Traefik, Tailscale Operator, DNS utils, testing, plus apps (anki, gotify, miniflux, nightscout, radicale, redmine, slimserve, syncstorage-rs, umami) |

---

### Dependency Graph

```mermaid
graph TD
  subgraph MODULES["Modules"]
    LE["Let's Encrypt"]
    CF["Cloudflare"]
    TPn["Talos"]
    TSn["Tailscale"]
    HZ["Hetzner"]

    subgraph INPUTS["Inputs"]
      V["prod.values.hcl<br>(reproducible configuration)"]
      S["secrets.hcl<br>(SOPS)"]
    end

    subgraph INFRA["Stack: infra"]
      direction TB
      TP["talos/pre<br>• Machine secrets<br>• .tmpl patch render"]
      HP["hetzner/post<br>• Firewall<br>• hcloud_server"]
      TSP["tailscale/post<br>• Device records<br>• Cleanup on destroy"]
      TAP["talos/post<br>• Config apply<br>• etcd bootstrap<br>• kubeconfig"]
      CP["cloudflare/post<br>• A/AAAA / CNAME"]
      TP --> HP --> TSP --> TAP --> CP
    end

    subgraph MANIFESTS["Stack: manifests"]
      direction TB
      subgraph CORE["Core"]
        ATL["atlantis"]
        LH["longhorn"]
        S3["s3-csi"]
        RF["reflector"]
        CNPG["cnpg"]
        PSMDB["psmdb-operator"]
        MONGO["mongodb-community-operator"]
        KPS["kube-prometheus-stack"]
        LOKI["loki"]
        ALLOY["alloy"]
        DNS["dnsutils"]
        TSO["tailscale-operator"]
        CM["cert-manager"]
        DESCHED["descheduler"]
        TF["traefik"]
        TS["testing"]
      end
      subgraph APPS["Apps"]
        ANKI["anki"]
        GOTIFY["gotify"]
        MINI["miniflux"]
        NS["nightscout"]
        RAD["radicale"]
        RED["redmine"]
        SLIM["slimserve"]
        SYNC["syncstorage-rs"]
        UMA["umami"]
      end
      CP -.->|DNS / API ready| LH
      LH --> RF & CNPG & PSMDB & MONGO & KPS & TSO
      LH & KPS --> LOKI
      KPS --> ALLOY
      GOTIFY --> KPS
      RF & CNPG & KPS --> CM
      CM & LH --> ATL
      CM --> TF & TS & DNS & RAD & GOTIFY
      CM & CNPG --> ANKI & MINI & RED & UMA & SYNC
      CM & MONGO --> NS
      S3 & CM --> SLIM
    end
  end

  V & S --> INFRA
  V & S --> MANIFESTS

  HP -.-> HZ
  TSP -.-> TSn
  TAP -.-> TPn
  TP -.-> TPn
  CP -.-> CF
  CM -.-> LE

  classDef infraTarget fill:#0ea5e9,stroke:#0369a1,color:#fff;     
  classDef coreTarget fill:#10b981,stroke:#065f46,color:#fff;       
  classDef appTarget fill:#f59e0b,stroke:#92400e,color:#fff;       
  classDef inputTarget fill:#1f2937,stroke:#374151,color:#fff;     
  classDef internalTarget fill:#ef4444,stroke:#7f1d1d,color:#fff;  
  classDef externalTarget fill:#111827,stroke:#6b7280,color:#fff;

  class INPUTS inputTarget;
  class TP,HP,TSP,TAP,CP infraTarget;
  class ATL,LH,S3,RF,CNPG,PSMDB,MONGO,KPS,LOKI,ALLOY,DNS,TSO,CM,DESCHED,TF,TS coreTarget;
  class ANKI,GOTIFY,MINI,NS,RAD,RED,SLIM,SYNC,UMA appTarget;
  class HZ,TSn,CF,TPn,LE,V,S internalTarget;
  class INFRA,MANIFESTS,CORE,APPS inputTarget;
  class MODULES externalTarget;

  linkStyle default stroke:#fff,stroke-width:2px;
```

> [!NOTE]
> Dependencies are defined in module `terragrunt.hcl` files via `dependency` blocks.
> The `skip_outputs` setting uses `common.hcl` locals to enable plan/destroy without
> applied upstream state. Mock outputs match actual output types for type safety.

---

### Repository Layout

```
/
├── terragrunt.stack.hcl               # Root stack: infra + manifests value injection
├── prod.values.hcl                    # Single source of truth (cluster, nodes, app versions)
├── secrets.hcl                        # Never committed in plain text; encrypted with SOPS
├── secrets.hcl.example                # Template
├── .sops.yaml                         # SOPS / age rules
├── atlantis.yaml                      # Repo-level Atlantis project config
├── CODEOWNERS                         # Required reviewers / code ownership
├── Makefile                           # generate, plan, apply, SOPS, packer, lint
├── modules/
│   ├── common.hcl                     # Backend, provider versions, mock outputs, mock_infra, mock_apps
│   ├── infra/                         # Base infrastructure modules (Talos, Hetzner, Tailscale, Cloudflare)
│   │   ├── terragrunt.stack.hcl       # Defines infra stack units and dependencies
│   │   ├── talos/
│   │   │   ├── pre/                   # Machine secrets + config generation
│   │   │   ├── post/                  # Config apply, bootstrap, kubeconfig
│   │   │   └── templates/             # .tmpl patch files
│   │   ├── hetzner/
│   │   │   ├── pre/                   # Placeholder (no resources)
│   │   │   └── post/                  # Servers, firewall, private network
│   │   ├── tailscale/
│   │   │   ├── pre/                   # Placeholder (no resources)
│   │   │   └── post/                  # Device discovery, IP resolution
│   │   └── cloudflare/
│   │       ├── pre/                   # Placeholder (no resources)
│   │       └── post/                  # DNS records (A/AAAA/CNAME)
│   └── manifests/                     # Application modules
│       ├── terragrunt.stack.hcl       # Defines manifests stack units and dependencies
│       ├── core/
│       │   ├── alloy/                 # Grafana Alloy metrics/logs agent
│       │   ├── atlantis/              # Atlantis automation server
│       │   ├── cert-manager/          # ACME certificates + Gateway
│       │   ├── cnpg/                  # CloudNativePG operator
│       │   ├── descheduler/           # Pod rebalancing (RemoveDuplicates, LowNodeUtilization)
│       │   ├── dnsutils/              # Debug DNS utilities
│       │   ├── kube-prometheus-stack/ # Monitoring stack (pre + post)
│       │   ├── loki/                  # Distributed log aggregation (S3-backed)
│       │   ├── longhorn/              # Distributed block storage
│       │   ├── mongodb-community-operator/ # MongoDB Community Operator
│       │   ├── psmdb-operator/        # Percona MongoDB operator
│       │   ├── reflector/             # Secret/configmap reflection
│       │   ├── s3-csi/                # S3-compatible storage CSI driver
│       │   ├── tailscale-operator/    # Tailscale Kubernetes operator
│       │   ├── testing/               # Smoke tests (nginx, echoserver)
│       │   └── traefik/               # Traefik Gateway API provider
│       └── apps/
│           ├── template/              # App template for new applications
│           ├── anki/                  # Anki sync server
│           ├── gotify/                # Push notification relay
│           ├── miniflux/              # RSS reader
│           ├── nightscout/            # CGM data visualization
│           ├── radicale/              # CalDAV/CardDAV server
│           ├── redmine/               # Project management
│           ├── slimserve/             # Lightweight file server
│           ├── syncstorage-rs/        # Firefox Sync storage
│           └── umami/                 # Web analytics
│
└── packer/                            # Optional Talos image build for Hetzner
    ├── hetzner.pkr.hcl                # Packer template
    ├── prod.pkrvars.hcl               # Packer variables (image name, Talos version)
    ├── secret.hcl                     # Packer-specific SOPS-encrypted secrets
    └── ...
```

> [!NOTE]
> When `make generate` runs, Terragrunt reads `terragrunt.stack.hcl` and generates unit
> directories under **`.terragrunt-stack/`**; the Makefile cleans these intermediate
> directories after plan/apply. Each module's `terragrunt.hcl` includes `common.hcl` for
> shared backend config, provider versions, and mock outputs.

<br>

## Other Environments

Production is defined by **`terragrunt.stack.hcl`** and **`prod.values.hcl`**. For another
environment (e.g., dev), create `dev.values.hcl` and use `make apply ENV=dev`. The stack
file reads the matching `*.values.hcl` based on the `STACK_ENV` environment variable.

<br>

## License

[AGPL-3.0](LICENSE)
