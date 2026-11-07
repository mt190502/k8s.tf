## ============================================================================================= ##
#  modules/manifests/core/trivy/dashboard.tf                                                      #
## ============================================================================================= ##
resource "kubernetes_config_map_v1" "dashboard" {
  metadata {
    name      = "trivy-operator-dashboard"
    namespace = kubernetes_namespace_v1.this.metadata[0].name
    labels = {
      "grafana_dashboard"         = "1"
      "app.kubernetes.io/part-of" = helm_release.this.name
    }
  }
  data = {
    "trivy-operator-dashboard.json" = <<-JSON
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "refresh": "5m",
  "schemaVersion": 39,
  "tags": [
    "trivy",
    "security"
  ],
  "time": {
    "from": "now-7d",
    "to": "now"
  },
  "timezone": "browser",
  "title": "Trivy Security",
  "uid": "trivy-security",
  "version": 1,
  "templating": {
    "list": [
      {
        "name": "datasource",
        "type": "datasource",
        "query": "prometheus",
        "refresh": 1,
        "current": {
          "text": "Prometheus",
          "value": "prometheus"
        }
      }
    ]
  },
  "panels": [
    {
      "id": 111,
      "title": "12 \u00b7 Security / Trivy",
      "type": "row",
      "collapsed": false,
      "gridPos": {
        "h": 1,
        "w": 24,
        "x": 0,
        "y": 211
      },
      "panels": []
    },
    {
      "id": 112,
      "title": "Images with fixable CRITICAL",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 5,
        "w": 4,
        "x": 0,
        "y": 212
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "count(max by (image_registry,image_repository,image_tag) (trivy_image_vulnerabilities{severity=\"Critical\"}) > 0) or vector(0)",
          "legendFormat": "",
          "instant": true
        }
      ],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "id": 113,
      "title": "Images with fixable HIGH",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 5,
        "w": 4,
        "x": 4,
        "y": 212
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "orange",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "count(max by (image_registry,image_repository,image_tag) (trivy_image_vulnerabilities{severity=\"High\"}) > 0) or vector(0)",
          "legendFormat": "",
          "instant": true
        }
      ],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "id": 114,
      "title": "Distinct CRITICAL CVEs",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 5,
        "w": 4,
        "x": 8,
        "y": 212
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "count(count by (vuln_id) (trivy_vulnerability_id{severity=\"Critical\"})) or vector(0)",
          "legendFormat": "",
          "instant": true
        }
      ],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "id": 115,
      "title": "Exposed secrets in images",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 5,
        "w": 4,
        "x": 12,
        "y": 212
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "green",
                "value": null
              },
              {
                "color": "red",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "sum(max by (image_registry,image_repository,image_tag,severity) (trivy_image_exposedsecrets)) or vector(0)",
          "legendFormat": "",
          "instant": true
        }
      ],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "id": 116,
      "title": "Scanned workloads",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 5,
        "w": 4,
        "x": 16,
        "y": 212
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "blue",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "count(count by (namespace,resource_kind,resource_name,container_name) (trivy_image_vulnerabilities)) or vector(0)",
          "legendFormat": "",
          "instant": true
        }
      ],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "id": 117,
      "title": "Scanner",
      "type": "stat",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 5,
        "w": 4,
        "x": 20,
        "y": 212
      },
      "fieldConfig": {
        "defaults": {
          "unit": "none",
          "mappings": [
            {
              "type": "value",
              "options": {
                "0": {
                  "text": "DOWN",
                  "color": "red"
                },
                "1": {
                  "text": "UP",
                  "color": "green"
                }
              }
            }
          ],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {
                "color": "red",
                "value": null
              },
              {
                "color": "green",
                "value": 1
              }
            ]
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "min(up{job=\"trivy-operator\"}) or vector(0)",
          "legendFormat": "",
          "instant": true
        }
      ],
      "options": {
        "colorMode": "background",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": [
            "lastNotNull"
          ],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      }
    },
    {
      "id": 118,
      "title": "Vulnerable images (fixable)",
      "type": "table",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 0,
        "y": 217
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "custom": {
            "filterable": true
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Critical"
            },
            "properties": [
              {
                "id": "custom.cellOptions",
                "value": {
                  "type": "color-background"
                }
              },
              {
                "id": "thresholds",
                "value": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "transparent",
                      "value": null
                    },
                    {
                      "color": "red",
                      "value": 1
                    }
                  ]
                }
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "High"
            },
            "properties": [
              {
                "id": "custom.cellOptions",
                "value": {
                  "type": "color-background"
                }
              },
              {
                "id": "thresholds",
                "value": {
                  "mode": "absolute",
                  "steps": [
                    {
                      "color": "transparent",
                      "value": null
                    },
                    {
                      "color": "orange",
                      "value": 1
                    }
                  ]
                }
              }
            ]
          }
        ]
      },
      "targets": [
        {
          "refId": "A",
          "expr": "max by (image_registry,image_repository,image_tag) (trivy_image_vulnerabilities{severity=\"Critical\"}) and on (image_registry,image_repository,image_tag) (count by (image_registry,image_repository,image_tag) (trivy_image_vulnerabilities{severity=~\"Critical|High\"} > 0))",
          "format": "table",
          "instant": true
        },
        {
          "refId": "B",
          "expr": "max by (image_registry,image_repository,image_tag) (trivy_image_vulnerabilities{severity=\"High\"}) and on (image_registry,image_repository,image_tag) (count by (image_registry,image_repository,image_tag) (trivy_image_vulnerabilities{severity=~\"Critical|High\"} > 0))",
          "format": "table",
          "instant": true
        },
        {
          "refId": "C",
          "expr": "count by (image_registry,image_repository,image_tag) (count by (image_registry,image_repository,image_tag,namespace,resource_kind,resource_name) (trivy_image_vulnerabilities{severity=~\"Critical|High\"} > 0))",
          "format": "table",
          "instant": true
        }
      ],
      "transformations": [
        {
          "id": "merge",
          "options": {}
        },
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true
            },
            "indexByName": {
              "image_registry": 0,
              "image_repository": 1,
              "image_tag": 2,
              "Value #A": 3,
              "Value #B": 4,
              "Value #C": 5
            },
            "renameByName": {
              "image_registry": "Registry",
              "image_repository": "Image",
              "image_tag": "Tag",
              "Value #A": "Critical",
              "Value #B": "High",
              "Value #C": "Workloads"
            }
          }
        }
      ],
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "showHeader": true,
        "sortBy": [
          {
            "displayName": "Critical",
            "desc": true
          }
        ]
      }
    },
    {
      "id": 119,
      "title": "Fixable CRITICAL / HIGH CVEs",
      "type": "table",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 10,
        "w": 12,
        "x": 12,
        "y": 217
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "custom": {
            "filterable": true
          }
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Severity"
            },
            "properties": [
              {
                "id": "custom.cellOptions",
                "value": {
                  "type": "color-text"
                }
              },
              {
                "id": "mappings",
                "value": [
                  {
                    "type": "value",
                    "options": {
                      "Critical": {
                        "color": "red",
                        "index": 0
                      },
                      "High": {
                        "color": "orange",
                        "index": 1
                      }
                    }
                  }
                ]
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "CVE"
            },
            "properties": [
              {
                "id": "links",
                "value": [
                  {
                    "title": "Open in NVD",
                    "url": "https://nvd.nist.gov/vuln/detail/$${__value.raw}",
                    "targetBlank": true
                  }
                ]
              }
            ]
          }
        ]
      },
      "targets": [
        {
          "refId": "A",
          "expr": "count by (vuln_id, severity, vuln_score, resource, installed_version, fixed_version, vuln_title) (trivy_vulnerability_id{severity=~\"Critical|High\"})",
          "format": "table",
          "instant": true
        }
      ],
      "transformations": [
        {
          "id": "merge",
          "options": {}
        },
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true
            },
            "indexByName": {
              "severity": 0,
              "vuln_score": 1,
              "vuln_id": 2,
              "resource": 3,
              "installed_version": 4,
              "fixed_version": 5,
              "Value": 6,
              "vuln_title": 7
            },
            "renameByName": {
              "severity": "Severity",
              "vuln_score": "Score",
              "vuln_id": "CVE",
              "resource": "Package",
              "installed_version": "Installed",
              "fixed_version": "Fixed in",
              "Value": "Workloads",
              "vuln_title": "Title"
            }
          }
        }
      ],
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "showHeader": true,
        "sortBy": [
          {
            "displayName": "Score",
            "desc": true
          }
        ]
      }
    },
    {
      "id": 120,
      "title": "Fixable vulnerabilities over time (unique images)",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 7,
        "w": 12,
        "x": 0,
        "y": 227
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": []
        },
        "overrides": [
          {
            "matcher": {
              "id": "byName",
              "options": "Critical"
            },
            "properties": [
              {
                "id": "color",
                "value": {
                  "mode": "fixed",
                  "fixedColor": "red"
                }
              }
            ]
          },
          {
            "matcher": {
              "id": "byName",
              "options": "High"
            },
            "properties": [
              {
                "id": "color",
                "value": {
                  "mode": "fixed",
                  "fixedColor": "orange"
                }
              }
            ]
          }
        ]
      },
      "targets": [
        {
          "refId": "A",
          "expr": "sum by (severity) (max by (image_registry,image_repository,image_tag,severity) (trivy_image_vulnerabilities{severity=~\"Critical|High\"}))",
          "legendFormat": "{{severity}}",
          "instant": false
        }
      ],
      "options": {
        "legend": {
          "displayMode": "list",
          "placement": "bottom"
        },
        "tooltip": {
          "mode": "multi",
          "sort": "desc"
        }
      }
    },
    {
      "id": 121,
      "title": "Workloads with secrets baked into the image",
      "type": "table",
      "datasource": {
        "type": "prometheus",
        "uid": "$datasource"
      },
      "gridPos": {
        "h": 7,
        "w": 12,
        "x": 12,
        "y": 227
      },
      "fieldConfig": {
        "defaults": {
          "unit": "short",
          "mappings": [],
          "custom": {
            "filterable": true
          }
        },
        "overrides": []
      },
      "targets": [
        {
          "refId": "A",
          "expr": "sum by (namespace, resource_kind, resource_name, image_repository, image_tag) (trivy_image_exposedsecrets) > 0",
          "format": "table",
          "instant": true
        }
      ],
      "transformations": [
        {
          "id": "merge",
          "options": {}
        },
        {
          "id": "organize",
          "options": {
            "excludeByName": {
              "Time": true
            },
            "renameByName": {
              "namespace": "Namespace",
              "resource_kind": "Kind",
              "resource_name": "Workload",
              "image_repository": "Image",
              "image_tag": "Tag",
              "Value": "Secrets"
            }
          }
        }
      ],
      "options": {
        "cellHeight": "sm",
        "footer": {
          "countRows": false,
          "fields": "",
          "reducer": [
            "sum"
          ],
          "show": false
        },
        "showHeader": true,
        "sortBy": [
          {
            "displayName": "Secrets",
            "desc": true
          }
        ]
      }
    }
  ]
}
    JSON
  }
}
