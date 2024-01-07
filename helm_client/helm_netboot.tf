# kea #

resource "helm_release" "kea" {
  name  = "kea"
  chart = "${path.module}/output/charts/kea"
  wait  = false
}

# matchbox with data sync #

resource "helm_release" "matchbox" {
  name  = "matchbox"
  chart = "${path.module}/output/charts/matchbox"
  wait  = false
}