## ============================================================================================= ##
#  modules/manifests/core/cnpg/apf.tf                                                              #
#                                                                                                 #
#  API Priority and Fairness (APF) FlowSchema + PriorityLevelConfiguration for CNPG                #
#  instance-manager Pods. Each postgres instance runs `/controller/manager instance                #
#  run` (controller-runtime) and polls its own `Cluster` resource frequently. When a              #
#  new watch event arrives, controller-runtime cancels in-flight GET requests; apiserver           #
#  then fails to write the response and logs E-level "Handler timeout" / "context canceled"        #
#  noise.                                                                                          #
#                                                                                                 #
#  Strategy:                                                                                       #
#    - A dedicated PriorityLevelConfiguration with low nominalConcurrencyShares so CNPG            #
#      poll requests get queued.                                                                  #
#    - A FlowSchema matching all ServiceAccount subjects (via system:serviceaccounts group)       #
#      but ONLY for postgresql.cnpg.io/clusters get/list/watch requests. Other SA traffic          #
#      still falls through to the built-in service-accounts FlowSchema (precedence 9000).         #
#    - matchingPrecedence 8000 < 9000, so CNPG cluster polls are caught here first.               #
#    - When the client cancels a queued request, APF dequeues it silently — no apiserver E log.   #
## ============================================================================================= ##
resource "kubernetes_manifest" "apf_priority_level" {
  manifest = {
    apiVersion = "flowcontrol.apiserver.k8s.io/v1"
    kind       = "PriorityLevelConfiguration"
    metadata = {
      name = "cnpg-instance-managers"
    }
    spec = {
      type = "Limited"
      limited = {
        nominalConcurrencyShares = 10
        lendablePercent          = 50
        limitResponse = {
          type = "Queue"
          queuing = {
            queues           = 64
            handSize         = 6
            queueLengthLimit = 50
          }
        }
      }
    }
  }
}

resource "kubernetes_manifest" "apf_flow_schema" {
  manifest = {
    apiVersion = "flowcontrol.apiserver.k8s.io/v1"
    kind       = "FlowSchema"
    metadata = {
      name = "cnpg-instance-managers"
    }
    spec = {
      priorityLevelConfiguration = {
        name = "cnpg-instance-managers"
      }
      matchingPrecedence = 8000
      distinguisherMethod = {
        type = "ByUser"
      }
      rules = [
        {
          subjects = [
            {
              kind = "Group"
              group = {
                name = "system:serviceaccounts"
              }
            }
          ]
          resourceRules = [
            {
              apiGroups  = ["postgresql.cnpg.io"]
              namespaces = ["*"]
              resources  = ["clusters"]
              verbs      = ["get", "list", "watch"]
            }
          ]
        }
      ]
    }
  }
  depends_on = [kubernetes_manifest.apf_priority_level]
}