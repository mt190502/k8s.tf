## ============================================================================================= ##
#  modules/manifests/core/loki/helm.tf                                                            #
## ============================================================================================= ##
resource "helm_release" "this" {
  name            = "loki"
  repository      = "https://grafana-community.github.io/helm-charts"
  chart           = "loki"
  version         = "18.5.4"
  namespace       = var.config.kps_namespace
  upgrade_install = true
  set = [
    {
      name  = "backend.replicas",
      value = "0"
    },
    {
      name  = "bloomBuilder.replicas",
      value = "0"
    },
    {
      name  = "bloomGateway.replicas",
      value = "0"
    },
    {
      name  = "bloomPlanner.replicas",
      value = "0"
    },
    {
      name  = "compactor.replicas",
      value = "0"
    },
    {
      name  = "deploymentMode"
      value = "SingleBinary"
    },
    {
      name  = "singleBinary.replicas"
      value = "1"
    },
    {
      name  = "distributor.replicas",
      value = "0"
    },
    {
      name  = "indexGateway.replicas",
      value = "0"
    },
    {
      name  = "ingester.replicas",
      value = "0"
    },
    {
      name  = "loki.auth_enabled",
      value = "false"
    },
    {
      name  = "loki.commonConfig.replication_factor"
      value = "1"
    },
    {
      name  = "loki.limits_config.allow_structured_metadata",
      value = "true"
    },
    {
      name  = "loki.limits_config.volume_enabled",
      value = "true"
    },
    {
      name  = "loki.pattern_ingester.enabled",
      value = "true"
    },
    {
      name  = "loki.ruler.enable_api",
      value = "true"
    },
    {
      name  = "loki.rulerConfig.alertmanager_url"
      value = "http://kube-prometheus-stack-alertmanager.${var.config.kps_namespace}.svc:9093"
    },
    {
      name  = "loki.rulerConfig.rule_path"
      value = "/etc/loki/rules"
    },
    {
      name  = "loki.rulerConfig.storage.type"
      value = "local"
    },
    {
      name  = "loki.rulerConfig.storage.local.directory"
      value = "/etc/loki/rules"
    },
    {
      name  = "loki.schemaConfig.configs[0].from",
      value = "2024-01-01"
    },
    {
      name  = "loki.schemaConfig.configs[0].index.period",
      value = "24h"
    },
    {
      name  = "loki.schemaConfig.configs[0].index.prefix",
      value = "loki_index_"
    },
    {
      name  = "loki.schemaConfig.configs[0].object_store",
      value = "s3"
    },
    {
      name  = "loki.schemaConfig.configs[0].schema",
      value = "v13"
    },
    {
      name  = "loki.schemaConfig.configs[0].store",
      value = "tsdb"
    },
    {
      name  = "loki.storage.bucketNames.admin",
      value = "loki"
    },
    {
      name  = "loki.storage.bucketNames.chunks",
      value = "loki"
    },
    {
      name  = "loki.storage.bucketNames.ruler",
      value = "loki"
    },
    {
      name  = "loki.storage.s3.endpoint",
      value = var.config.endpoint
    },
    {
      name  = "loki.storage.s3.region",
      value = "eu-central-1"
    },
    {
      name  = "loki.storage.s3.region",
      value = var.config.region
    },
    {
      name  = "loki.storage.s3.s3",
      value = var.config.s3
    },
    {
      name  = "loki.storage.s3.s3ForcePathStyle",
      value = var.config.force_path_style
    },
    {
      name  = "loki.storage.type",
      value = "s3"
    },
    {
      name  = "lokiCanary.enabled",
      value = "false"
    },
    {
      name  = "chunksCache.enabled",
      value = "false"
    },
    {
      name  = "memcached.enabled",
      value = "false"
    },
    {
      name  = "resultsCache.enabled",
      value = "false"
    },
    {
      name  = "minio.enabled",
      value = "false"
    },
    {
      name  = "querier.replicas",
      value = "0"
    },
    {
      name  = "queryFrontend.replicas",
      value = "0"
    },
    {
      name  = "queryScheduler.replicas",
      value = "0"
    },
    {
      name  = "read.replicas",
      value = "0"
    },
    {
      name  = "serviceMonitor.enabled",
      value = "true"
    },
    {
      name  = "singleBinary.persistence.size"
      value = "2Gi"
    },
    {
      name  = "singleBinary.replicas",
      value = "1"
    },
    {
      name  = "test.enabled",
      value = "false"
    },
    {
      name  = "write.replicas",
      value = "0"
    }
  ]
  set_sensitive = [
    {
      name  = "loki.storage.s3.accessKeyId",
      value = var.secrets.access_key_id
    },
    {
      name  = "loki.storage.s3.secretAccessKey",
      value = var.secrets.secret_access_key
    }
  ]
  values = [yamlencode({
    singleBinary = {
      extraVolumes = [
        {
          name = "loki-rules-source"
          configMap = {
            name = kubernetes_config_map_v1.loki_rules.metadata[0].name
          }
        },
        {
          name     = "loki-rules-writable"
          emptyDir = {}
        }
      ]
      extraVolumeMounts = [
        {
          name      = "loki-rules-source"
          mountPath = "/etc/loki/rules-source"
        },
        {
          name      = "loki-rules-writable"
          mountPath = "/etc/loki/rules/fake"
        }
      ]
      initContainers = [
        {
          name    = "rules-copy"
          image   = "busybox:1.36"
          command = ["/bin/sh", "-c"]
          args = [
            "cp /etc/loki/rules-source/* /etc/loki/rules/fake/"
          ]
          volumeMounts = [
            {
              name      = "loki-rules-source"
              mountPath = "/etc/loki/rules-source"
              readOnly  = true
            },
            {
              name      = "loki-rules-writable"
              mountPath = "/etc/loki/rules/fake"
            }
          ]
        }
      ]
    }
  })]
  depends_on = [kubernetes_config_map_v1.loki_rules]
}
