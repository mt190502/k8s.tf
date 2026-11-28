## ============================================================================================= ##
#  Require CPU/memory requests and a memory limit on regular Pod containers.                      #
#  CPU limits are intentionally optional. Init containers are outside this first-stage policy.    #
## ============================================================================================= ##
resource "kubernetes_manifest" "require_pod_resources" {
  manifest = {
    apiVersion = "policies.kyverno.io/v1"
    kind       = "ValidatingPolicy"
    metadata = {
      name = "require-pod-resources"
    }
    spec = {
      validationActions = ["Deny"]
      evaluation = {
        admission  = { enabled = true }
        background = { enabled = true }
      }
      matchConstraints = {
        namespaceSelector = {
          matchExpressions = [
            {
              key      = "kubernetes.io/metadata.name"
              operator = "NotIn"
              values   = ["kube-system", "longhorn-system"]
            }
          ]
        }
        objectSelector = {
          matchExpressions = [
            {
              key      = "s3.csi.aws.com/mounted-by-csi-driver-version"
              operator = "DoesNotExist"
            },
            {
              key      = "tailscale.com/managed"
              operator = "DoesNotExist"
            }
          ]
        }
        resourceRules = [
          {
            apiGroups   = [""]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["pods"]
            scope       = "Namespaced"
          }
        ]
      }
      validations = [
        {
          message    = "Every regular container must set requests.cpu, requests.memory, and limits.memory. CPU limits are optional."
          expression = "(has(object.metadata.labels) && ('s3.csi.aws.com/mounted-by-csi-driver-version' in object.metadata.labels || 'tailscale.com/managed' in object.metadata.labels)) || object.spec.containers.all(c, has(c.resources) && has(c.resources.requests) && 'cpu' in c.resources.requests && 'memory' in c.resources.requests && has(c.resources.limits) && 'memory' in c.resources.limits)"
        }
      ]
    }
  }
}

## ============================================================================================= ##
#  Enforce that Longhorn PVCs excluded from recurring jobs are always in the trim group.          #
## ============================================================================================= ##
resource "kubernetes_manifest" "require_trim_on_excluded_pvc" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "MutatingAdmissionPolicy"
    metadata = {
      name = "longhorn-excluded-pvc-gets-trim"
    }
    spec = {
      failurePolicy = "Fail"
      matchConstraints = {
        resourceRules = [
          {
            apiGroups   = [""]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["persistentvolumeclaims"]
            scope       = "Namespaced"
          }
        ]
      }
      matchConditions = [
        {
          name       = "is-longhorn"
          expression = "object.spec.storageClassName == 'longhorn'"
        },
        {
          name       = "excluded-from-recurring-jobs"
          expression = "has(object.metadata.labels) && 'recurring-job-group.longhorn.io/no-recurring-job' in object.metadata.labels && object.metadata.labels['recurring-job-group.longhorn.io/no-recurring-job'] == 'enabled'"
        },
        {
          name       = "trim-missing"
          expression = "!has(object.metadata.labels) || !('recurring-job-group.longhorn.io/trim' in object.metadata.labels) || object.metadata.labels['recurring-job-group.longhorn.io/trim'] != 'enabled'"
        }
      ]
      mutations = [
        {
          patchType = "JSONPatch"
          jsonPatch = {
            expression = "[JSONPatch{op: 'add', path: '/metadata/labels/' + jsonpatch.escapeKey('recurring-job-group.longhorn.io/trim'), value: 'enabled'}]"
          }
        }
      ]
      reinvocationPolicy = "IfNeeded"
    }
  }
}

resource "kubernetes_manifest" "require_trim_on_excluded_pvc_binding" {
  manifest = {
    apiVersion = "admissionregistration.k8s.io/v1"
    kind       = "MutatingAdmissionPolicyBinding"
    metadata = {
      name = "longhorn-excluded-pvc-gets-trim"
    }
    spec = {
      policyName = kubernetes_manifest.require_trim_on_excluded_pvc.manifest.metadata.name
      matchResources = {
        resourceRules = [
          {
            apiGroups   = [""]
            apiVersions = ["v1"]
            operations  = ["CREATE", "UPDATE"]
            resources   = ["persistentvolumeclaims"]
            scope       = "Namespaced"
          }
        ]
      }
    }
  }
  depends_on = [kubernetes_manifest.require_trim_on_excluded_pvc]
}
