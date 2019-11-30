module "libvirt-kvm-0" {
  source = "../modulesv2/libvirt"

  libvirt_url = "qemu+ssh://core@192.168.127.251/system"
  guests = {
    gateway-0 = {
      memory = 2
      vcpu   = 2
      disk   = []
      network = [
        {
          if = "en-store"
        },
        {
          if = "en-lan"
        },
        {
          if = "en-sync"
        },
        {
          if  = "en-wan"
          mac = "52:54:00:63:6e:b2"
        },
        {
          if  = "en-wan"
          mac = "52:54:00:63:6e:b3"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:2a"
          bootorder = 1
        }
      ]
      hostdev = []
    }
    controller-0 = {
      memory = 4
      vcpu   = 2
      disk   = []
      network = [
        {
          if = "en-store"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:0a"
          bootorder = 1
        }
      ]
      hostdev = []
    }
    worker-0 = {
      memory = 32
      vcpu   = 4
      disk = [
        {
          source = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M414895K"
          target = "vda"
        }
      ]
      network = [
        {
          if = "en-store"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:1a"
          bootorder = 1
        }
      ]
      hostdev = [
        {
          domain   = "0x0000"
          bus      = "0x05"
          slot     = "0x00"
          function = "0x0"
          rom      = "/var/lib/libvirt/boot/SAS9300_8i_IT.bin"
        }
      ]
    }
  }
}

module "libvirt-kvm-1" {
  source = "../modulesv2/libvirt"

  libvirt_url = "qemu+ssh://core@192.168.127.252/system"
  guests = {
    gateway-1 = {
      memory = 2
      vcpu   = 2
      disk   = []
      network = [
        {
          if = "en-store"
        },
        {
          if = "en-lan"
        },
        {
          if = "en-sync"
        },
        {
          if  = "en-wan"
          mac = "52:54:00:63:6e:b1"
        },
        {
          if  = "en-wan"
          mac = "52:54:00:63:6e:b3"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:2b"
          bootorder = 1
        }
      ]
      hostdev = []
    }
    controller-1 = {
      memory = 4
      vcpu   = 2
      disk   = []
      network = [
        {
          if = "en-store"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:0b"
          bootorder = 1
        }
      ]
      hostdev = []
    }
    controller-2 = {
      memory = 4
      vcpu   = 2
      disk   = []
      network = [
        {
          if = "en-store"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:0c"
          bootorder = 1
        }
      ]
      hostdev = []
    }
    worker-1 = {
      memory = 32
      vcpu   = 4
      disk = [
        {
          source = "/dev/disk/by-id/ata-Samsung_SSD_860_QVO_1TB_S4PGNF0M410395Z"
          target = "vda"
        }
      ]
      network = [
        {
          if = "en-store"
        },
        {
          if        = "en-int"
          mac       = "52:54:00:1a:61:1b"
          bootorder = 1
        }
      ]
      hostdev = [
        {
          domain   = "0x0000"
          bus      = "0x05"
          slot     = "0x00"
          function = "0x0"
          rom      = "/var/lib/libvirt/boot/SAS9300_8i_IT.bin"
        }
      ]
    }
  }
}