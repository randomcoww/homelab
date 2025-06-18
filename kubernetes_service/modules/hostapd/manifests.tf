resource "random_id" "hostapd-encryption-key" {
  byte_length = 16
}

resource "random_id" "hostapd-mobility-domain" {
  byte_length = 2
}

locals {
  config_path = "/etc/hostapd/hostapd.conf"
  ids = [
    for i in range(var.replicas) :
    format("%X", var.bssid_base + i)
  ]

  peers = [
    for i, id in local.ids :
    {
      bssid          = join(":", regexall("\\w{2}", id))
      r1_key_holder  = id
      nas_identifier = id
    }
  ]

  r0kh = [
    for peer in local.peers :
    "${peer.bssid} ${peer.nas_identifier} ${random_id.hostapd-encryption-key.hex}"
  ]

  r1kh = [
    for peer in local.peers :
    "${peer.bssid} ${peer.bssid} ${random_id.hostapd-encryption-key.hex}"
  ]

  peer_configs = [
    for peer in local.peers :
    merge(peer, {
      r0kh                  = local.r0kh
      r1kh                  = local.r1kh
      pmk_r1_push           = 1
      ft_psk_generate_local = 1
      mobility_domain       = random_id.hostapd-mobility-domain.hex
    }, var.config)
  ]
}

module "metadata" {
  source      = "../../../modules/metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.hostapd)[1]
  manifests = {
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source    = "../../../modules/secret"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  data = {
    for i, config in local.peer_configs :
    "${var.name}-${var.name}-${i}" => join("\n", flatten([
      for k, values in config :
      try([
        for v in values :
        "${k}=${v}"
      ], "${k}=${values}")
    ]))
  }
}

module "statefulset" {
  source    = "../../../modules/statefulset"
  name      = var.name
  namespace = var.namespace
  app       = var.name
  release   = var.release
  affinity  = var.affinity
  replicas  = var.replicas
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  template_spec = {
    hostNetwork = true
    dnsPolicy   = "ClusterFirstWithHostNet"
    containers = [
      {
        name  = var.name
        image = var.images.hostapd
        args = [
          local.config_path,
        ]
        env = [
          {
            name = "POD_NAME"
            valueFrom = {
              fieldRef = {
                fieldPath = "metadata.name"
              }
            }
          },
        ]
        securityContext = {
          privileged = true
        }
        volumeMounts = [
          {
            name        = "hostapd-config"
            mountPath   = local.config_path
            subPathExpr = "hostapd-$(POD_NAME)"
          },
          {
            name      = "rfkill"
            mountPath = "/dev/rfkill"
          },
        ]
      },
    ]
    volumes = [
      {
        name = "hostapd-config"
        secret = {
          secretName = module.secret.name
        }
      },
      {
        name = "rfkill"
        hostPath = {
          path = "/dev/rfkill"
        }
      },
    ]
  }
}