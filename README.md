# k8s.tf - Kubernetes Cluster IaC with OpenTofu/Terraform + Terragrunt

End-to-end Kubernetes infrastructure managed with **OpenTofu** modules and orchestrated
by **Terragrunt** as a layered stack and DAG. The cluster runs on **Talos Linux**
with **Hetzner Cloud** for compute, **Tailscale** for node-to-node networking,
**Cloudflare DNS** for domain management, and core cluster services including storage,
observability, and certificate management.

**Key Features:**
- Multi-region Talos Kubernetes clusters with dual-stack networking
- Cilium CNI with WireGuard encryption for pod-to-pod communication
- Gateway API for ingress with Envoy load balancing
- SOPS + age encryption for sensitive configuration
- Terragrunt stack-based deployment with dependency management
- Centralized mock outputs for plan/destroy without applied state

<br>

## Architecture Overview

```mermaid
graph TD
  domain["srv.mtaha.dev"]
  cloudflare["Cloudflare<br/>Round Robin"]
  domain --> cloudflare

  subgraph TALOS["Talos Kubernetes Cluster"]
    subgraph STORAGE_STACK["StorageClass Stack"]
      storage_s3["S3"]
      storage_longhorn["Longhorn"]
    end
    tailscale["Tailscale<br>(node-to-node)<br>(UDP/41641)"]
    cilium_wg["Cilium WireGuard<br>(pod-to-pod)<br>(UDP/51871)"]
    subgraph NETWORK_STACK["Node Networking Stack"]
      route["HTTPRoute"]
      gateway["Gateway API"]
      envoy["Cilium Envoy"]
    end
    subgraph K8S["Apps"]
      cert["Cert Manager"]
      monitoring["Kube Prometheus Stack"]
      reflector["Reflector"]
      pg["CloudNative-PG"]
    end

    subgraph CLUSTER1["Cluster Group 1"]
      subgraph HEL1["🇫🇮 Helsinki"]
        m1a["m1 (CP)"]
        w1a["w1"]
      end

      subgraph NBG1["🇩🇪 Nuremberg"]
        m2a["m2 (CP)"]
        w2a["w2"]
      end

      subgraph FSN1["🇩🇪 Falkenstein"]
        m3a["m3 (CP)"]
        w3a["w3"]
      end
    end

    subgraph CLUSTER2["Cluster Group 2<br>(ClusterMesh W.I.P)"]
      subgraph LOC1["Another Location"]
        m1b["m1 (CP)"]
        w1b["w1"]
      end
    end
  end

  cloudflare -->|:443| m1a
  cloudflare -->|:443| w1a
  cloudflare -->|:443| m2a
  cloudflare -->|:443| w2a
  cloudflare -->|:443| m3a
  cloudflare -->|:443| w3a
  cloudflare -->|:443| m1b
  cloudflare -->|:443| w1b

  route <--> gateway <--> envoy
  m1a <-.-> route
  w1a <-.-> route
  m2a <-.-> route
  w2a <-.-> route
  m3a <-.-> route
  w3a <-.-> route
  m1b <-.-> route
  w1b <-.-> route

  cilium_wg <-.-> m1a
  cilium_wg <-.-> w1a
  cilium_wg <-.-> m2a
  cilium_wg <-.-> w2a
  cilium_wg <-.-> m3a
  cilium_wg <-.-> w3a
  cilium_wg <-.-> m1b
  cilium_wg <-.-> w1b
  tailscale <-.-> m1a
  tailscale <-.-> w1a
  tailscale <-.-> m2a
  tailscale <-.-> w2a
  tailscale <-.-> m3a
  tailscale <-.-> w3a
  envoy <---> K8S
  K8S <---> STORAGE_STACK

  classDef infra fill:#0ea5e9,stroke:#0369a1,color:#fff;
  classDef network fill:#8b5cf6,stroke:#5b21b6,color:#fff;
  classDef app fill:#10b981,stroke:#065f46,color:#fff;
  classDef storage fill:#f59e0b,stroke:#92400e,color:#fff;
  classDef node fill:#ef4444,stroke:#7f1d1d,color:#fff;

  class domain,cloudflare infra;
  class route,gateway,envoy,cilium_wg,tailscale network;
  class cert,monitoring,reflector,pg,K8S app;
  class storage_s3,storage_longhorn storage;
  class m1a,w1a,m2a,w2a,m3a,w3a,m1b,w1b node;

  style TALOS fill:#111827,stroke:#374151,color:#fff
  style STORAGE_STACK fill:#1f2937,stroke:#f59e0b,color:#fff
  style NETWORK_STACK fill:#1f2937,stroke:#8b5cf6,color:#fff
  style K8S fill:#1f2937,stroke:#10b981,color:#fff
  style CLUSTER1 fill:#1f2937,stroke:#3b82f6,color:#fff
  style CLUSTER2 fill:#1f2937,stroke:#6366f1,color:#fff,stroke-dasharray:5,5
  style HEL1 fill:#020617,stroke:#3b82f6,color:#fff
  style NBG1 fill:#020617,stroke:#3b82f6,color:#fff
  style FSN1 fill:#020617,stroke:#3b82f6,color:#fff
  style LOC1 fill:#020617,stroke:#6366f1,color:#fff,stroke-dasharray:5,5

  linkStyle default stroke:#fff,stroke-width:2px; 
	style storage_s3 stroke-width:1px,stroke-dasharray:5 5,stroke:#FFFFFF,fill:#737373
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

| Layer              | Content                                                                                                                                                                  |
|:------------------:|:------------------------------------------------------------------------------------------------------------------------------------------------------------------------:|
| **Infrastructure** | Talos machine secrets, patch templates, Hetzner servers + firewall, Tailscale devices, Talos bootstrap, kubeconfig, Cloudflare DNS records                              |
| **Manifests**      | Longhorn, Reflector, CloudNativePG (CNPG), kube-prometheus-stack, cert-manager, plus optional **testing** unit (nginx, echoserver)                                        |

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
      LH["longhorn"]
      RF["reflector"]
      CNPG["cnpg"]
      KPS["kube-prometheus-stack"]
      CM["cert-manager"]
      TS["testing"]
      CP -.->|DNS / API ready| LH
      LH --> RF
      LH --> CNPG
      LH --> KPS
      KPS --> CM
      CM --> TS
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
  classDef appTarget fill:#10b981,stroke:#065f46,color:#fff;       
  classDef inputTarget fill:#1f2937,stroke:#374151,color:#fff;     
  classDef internalTarget fill:#ef4444,stroke:#7f1d1d,color:#fff;  
  classDef externalTarget fill:#111827,stroke:#6b7280,color:#fff;

  class INPUTS inputTarget;
  class TP,HP,TSP,TAP,CP infraTarget;
  class LH,RF,CNPG,KPS,CM,TS appTarget;
  class HZ,TSn,CF,TPn,LE,V,S internalTarget;
  class INFRA,MANIFESTS inputTarget;
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
├── Makefile                           # generate, plan, apply, SOPS, packer, lint
├── modules/
│   ├── common.hcl                     # Backend, provider versions, mock outputs, shared helpers
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
│       └── core/
│           ├── longhorn/              # Distributed block storage
│           ├── reflector/             # Secret/configmap reflection
│           ├── cnpg/                  # CloudNativePG operator
│           ├── kube-prometheus-stack/ # Monitoring stack
│           ├── cert-manager/          # ACME certificates + Gateway
│           └── testing/               # Smoke tests (nginx, echoserver)
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
