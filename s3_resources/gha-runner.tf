module "gha-runner" {
  source               = "./modules/gha_runner"
  name                 = "gha"
  namespace            = "arc-runners"
  controller_namespace = "arc-systems"
  images = {
    gha_runner = local.container_images_digest.gha_runner
  }
  github_credentials = {
    username = var.github_username
    token    = var.github_token
  }
  ca_issuer_name    = local.kubernetes.cert_issuers.ca_internal
  registry_endpoint = "${local.endpoints.registry.service}:${local.service_ports.registry}"
  minio_endpoint    = "${local.endpoints.minio.service}:${local.service_ports.minio}"
  minio_user        = minio_iam_user.user["arc"]
}

resource "minio_s3_object" "fluxcd-gha-runner" {
  for_each = {
    "manifest.yaml" = join("\n---\n", module.gha-runner.manifests)
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "gha-runner/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.bucket["fluxcd"],
  ]
}