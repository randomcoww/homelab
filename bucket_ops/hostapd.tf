resource "random_password" "hostapd-ssid" {
  length  = 8
  special = false
}

resource "random_password" "hostapd-password" {
  length  = 32
  special = false
}

module "hostapd" {
  source   = "./modules/hostapd"
  name     = "hostapd"
  replicas = 1
  images = {
    hostapd = {
      repository = "reg.cluster.internal/randomcoww/hostapd"
      tag        = "v2.11.1785766888@sha256:b19d0e9c1de8914742f76c8014dc38e40c8805bcea21bc79ae7b02591de6472e" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/hostapd
    }
  }
  affinity = {
    nodeAffinity = {
      requiredDuringSchedulingIgnoredDuringExecution = {
        nodeSelectorTerms = [
          {
            matchExpressions = [
              {
                key      = "feature.node.kubernetes.io/hostapd-compat"
                operator = "In"
                values = [
                  "true",
                ]
              },
            ]
          },
        ]
      }
    }
  }
  # https://w1.fi/cgit/hostap/plain/hostapd/hostapd.conf
  config = {
    country_code                  = "PA"
    country3                      = "0x49"
    channel                       = 36
    ssid                          = random_password.hostapd-ssid.result
    sae_password                  = random_password.hostapd-password.result
    sae_pwe                       = 2
    sae_require_mfp               = 1
    interface                     = "wlan0"
    bridge                        = local.networks.lan.interface
    driver                        = "nl80211"
    wpa                           = 2
    wpa_key_mgmt                  = "SAE"
    wpa_pairwise                  = "CCMP GCMP"
    wpa_disable_eapol_key_retries = 1
    hw_mode                       = "a"
    ieee80211n                    = 1
    ieee80211ac                   = 1
    ieee80211ax                   = 1
    ieee80211be                   = 1
    ieee80211d                    = 0
    ieee80211h                    = 0
    ieee80211w                    = 2
    auth_algs                     = 1
    wmm_enabled                   = 1
    require_he                    = 1
    vht_oper_chwidth              = 2
    vht_oper_centr_freq_seg0_idx  = 50
    he_oper_chwidth               = 2
    he_oper_centr_freq_seg0_idx   = 50
    eht_oper_chwidth              = 2
    eht_oper_centr_freq_seg0_idx  = 50
    he_su_beamformer              = 1
    he_su_beamformee              = 1
    he_mu_beamformer              = 1
    eht_su_beamformer             = 1
    eht_su_beamformee             = 1
    eht_mu_beamformer             = 1
    multicast_to_unicast          = 1
    ht_capab = "[${join("][", [
      "LDPC",
      "HT40+",
      "HT40-",
      "SHORT-GI-20",
      "SHORT-GI-40",
      "TX-STBC",
      "RX-STBC1",
      "MAX-AMSDU-7935",
    ])}]"
    vht_capab = "[${join("][", [
      "RXLDPC",
      "SHORT-GI-80",
      "SHORT-GI-160",
      "TX-STBC-2BY1",
      "SU-BEAMFORMEE",
      "MU-BEAMFORMEE",
      "RX-ANTENNA-PATTERN",
      "TX-ANTENNA-PATTERN",
      "RX-STBC-1",
      "BF-ANTENNA-4",
      "MAX-MPDU-11454",
      "MAX-A-MPDU-LEN-EXP7",
      "VHT160",
    ])}]"
  }
}

module "qrcode-hostapd" {
  source    = "./modules/qrcode"
  name      = local.endpoints.qrcode-hostapd.name
  namespace = local.endpoints.qrcode-hostapd.namespace
  replicas  = 2
  images = {
    qrcode = {
      repository = "reg.cluster.internal/randomcoww/qrcode-resource"
      tag        = "v1785767482@sha256:63d8004712c83fcc22cb11dc55110cfa2d4804d45ecf174f6ceb3c3da2563001" # renovate: datasource=docker depName=reg.cluster.internal/randomcoww/qrcode-resource
    }
  }
  qrcode_value     = "WIFI:S:${random_password.hostapd-ssid.result};T:WPA;P:${random_password.hostapd-password.result};H:true;;"
  ingress_hostname = local.endpoints.qrcode-hostapd.ingress
  gateway_ref = {
    name      = local.services.cilium.name
    namespace = local.services.cilium.namespace
  }
  auth_backend_ref = {
    name      = local.endpoints.authelia.name
    namespace = local.endpoints.authelia.namespace
    port      = 80
  }
}

resource "minio_s3_object" "fluxcd-hostapd" {
  for_each = {
    "manifest.yaml" = join("\n---\n", distinct(concat(module.hostapd.manifests, module.qrcode-hostapd.manifests)))
    "kustomization.yaml" = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"
      resources = [
        "manifest.yaml"
      ]
    })
  }

  bucket_name  = "fluxcd"
  object_name  = "hostapd/${each.key}"
  content_type = "application/yaml"
  content      = each.value

  depends_on = [
    minio_s3_bucket.static-bucket["fluxcd"],
  ]
}