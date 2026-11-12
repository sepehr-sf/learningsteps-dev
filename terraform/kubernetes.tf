# Manage the existing LearningSteps namespace
resource "kubernetes_namespace_v1" "learningsteps" {
  metadata {
    name = "learningsteps"
  }
}
# Retrieve PostgreSQL credentials from Azure Key Vault
resource "kubernetes_manifest" "postgres_secret_provider" {
  manifest = {
    apiVersion = "secrets-store.csi.x-k8s.io/v1"
    kind       = "SecretProviderClass"

    metadata = {
      name      = "learningsteps-postgres"
      namespace = kubernetes_namespace_v1.learningsteps.metadata[0].name
    }

    spec = {
      provider = "azure"
      secretObjects = [
        {
          secretName = "learningsteps-postgres"
          type       = "Opaque"

          data = [
            {
              objectName = "postgres-connection-string"
              key        = "connection-string"
            }
          ]
        }
      ]
      parameters = {
        usePodIdentity         = "false"
        useVMManagedIdentity   = "true"
        userAssignedIdentityID = "34925d7a-6f6c-4ca8-ad1c-cc5e1c6385ae"
        keyvaultName           = "kv-learningsteps-731926"
        tenantId               = "c0531484-50fa-4ff2-97df-b1f2d4810603"

        objects = <<-EOT
          array:
            - |
              objectName: postgres-connection-string
              objectType: secret
              objectVersion: ""
        EOT
      }
    }
  }
}
# Deploy the LearningSteps API
resource "kubernetes_deployment_v1" "api" {
  metadata {
    name      = "learningsteps-api"
    namespace = kubernetes_namespace_v1.learningsteps.metadata[0].name

    labels = {
      app = "learningsteps-api"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "learningsteps-api"
      }
    }

    template {
      metadata {
        labels = {
          app = "learningsteps-api"
        }
      }

      spec {
        container {
          name  = "api"
          image = "learningstepsacr2026.azurecr.io/learningsteps-api:1.0.0"

          port {
            container_port = 8000
          }

          env {
            name = "DATABASE_URL"

            value_from {
              secret_key_ref {
                name = "learningsteps-postgres"
                key  = "connection-string"
              }
            }
          }

          volume_mount {
            name       = "postgres-secret"
            mount_path = "/mnt/secrets-store"
            read_only  = true
          }
        }

        volume {
          name = "postgres-secret"

          csi {
            driver    = "secrets-store.csi.k8s.io"
            read_only = true

            volume_attributes = {
              secretProviderClass = "learningsteps-postgres"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_manifest.postgres_secret_provider
  ]
}
# Expose the LearningSteps API inside the cluster/Loadbalancer
resource "kubernetes_service_v1" "api" {
  metadata {
    name      = "learningsteps-api"
    namespace = kubernetes_namespace_v1.learningsteps.metadata[0].name
  }

  spec {
    selector = {
      app = "learningsteps-api"
    }

    port {
      port        = 8000
      target_port = 8000
      protocol    = "TCP"
    }

    type = "LoadBalancer"
  }
}

# Calculate a checksum so SQL changes produce a new initialization Job.
locals {
  database_setup_checksum = substr(
    sha256(file("${path.module}/../database_setup.sql")),
    0,
    8
  )
}

# Store the database initialization SQL in Kubernetes.
resource "kubernetes_config_map_v1" "database_setup" {
  metadata {
    name = "learningsteps-db-init-${local.database_setup_checksum}"

    namespace = kubernetes_namespace_v1.learningsteps.metadata[0].name
  }

  data = {
    "database_setup.sql" = file("${path.module}/../database_setup.sql")
  }
}

# Execute the database initialization script against Azure PostgreSQL.
resource "kubernetes_job_v1" "database_init" {
  metadata {
    name = "learningsteps-db-init-${local.database_setup_checksum}"

    namespace = kubernetes_namespace_v1.learningsteps.metadata[0].name
  }

  spec {
    backoff_limit              = 3
    ttl_seconds_after_finished = 86400

    template {
      metadata {
        labels = {
          app = "learningsteps-db-init"
        }
      }

      spec {
        container {
          name  = "postgres-schema-init"
          image = "postgres:16"

          command = ["/bin/sh", "-c"]

          args = [
            "psql \"$DATABASE_URL\" -v ON_ERROR_STOP=1 -f /sql/database_setup.sql"
          ]

          env {
            name = "DATABASE_URL"

            value_from {
              secret_key_ref {
                name = "learningsteps-postgres"
                key  = "connection-string"
              }
            }
          }

          volume_mount {
            name       = "database-setup"
            mount_path = "/sql"
            read_only  = true
          }
        }

        volume {
          name = "database-setup"

          config_map {
            name = kubernetes_config_map_v1.database_setup.metadata[0].name
          }
        }

        restart_policy = "Never"
      }
    }
  }

  wait_for_completion = true

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    kubernetes_deployment_v1.api,
    kubernetes_config_map_v1.database_setup
  ]
}
