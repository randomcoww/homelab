module "trust-manager-ca-internal-secret" {
  source    = "../modules/secret"
  name      = "trust-manager-ca-internal"
  namespace = local.services.cert-manager.namespace
  app       = "trust-manager"
  release   = "0.1.0"
  data = merge({
    "tls.crt" = chomp(data.terraform_remote_state.host.outputs.internal_ca.cert_pem)
  })
}

resource "minio_s3_object" "fluxcd-trust-manager-crs" {
  for_each = {
    "manifest.yaml" = join("\n---\n", concat([
      for _, m in [
        {
          apiVersion = "trust.cert-manager.io/v1alpha1"
          kind       = "Bundle"
          metadata = {
            name = "trust-manager-ca-internal"
          }
          spec = {
            sources = [
              {
                secret = {
                  name = module.trust-manager-ca-internal-secret.name
                  key  = "tls.crt"
                }
              },
            ]
            target = {
              configMap = {
                key = "ca.crt"
              }
            }
          }
        },
        {
          apiVersion = "trust.cert-manager.io/v1alpha1"
          kind       = "Bundle"
          metadata = {
            name = "trust-manager-ca-internal-bundle"
          }
          spec = {
            sources = [
              {
                useDefaultCAs = true
              },
              {
                secret = {
                  name = module.trust-manager-ca-internal-secret.name
                  key  = "tls.crt"
                }
              },
            ]
            target = {
              configMap = {
                key = "ca.crt"
              }
            }
          }
        },
      ] :
      yamlencode(m)
      ], [
      module.trust-manager-ca-internal-secret.manifest,
    ]))
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "trust-manager-crs/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}