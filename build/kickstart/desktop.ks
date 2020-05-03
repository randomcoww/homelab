install
skipx
lang en_US.UTF-8
keyboard us
timezone --utc Etc/UTC
auth --useshadow --passalgo=sha512
firewall --disabled
zerombr
clearpart --all --disklabel=gpt
part / --size 5120 --fstype ext4
rootpw --lock --iscrypted locked
network
shutdown

%include http://127.0.0.1:8080/generic?ks=desktop

##############################################
## base packages
##############################################

repo --name=fedora --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch
repo --name=updates --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f$releasever&arch=$basearch
url --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch

%packages --excludeWeakdeps --excludedocs

## common
@core
cronie
chrony
logrotate
tmux
openssh-server
rsync
-plymouth
-plymouth-*

## required for livemedia-creator
fedora-logos
dracut-config-generic
dracut-live
-dracut-config-rescue
grub2-efi-x64-cdboot
shim
memtest86+
syslinux

%end

%post --erroronfail

##############################################
## networkd
##############################################

## fallback - override this
cat <<EOF > /etc/systemd/network/90-default.network
[Match]
Name=en*

[Link]
ARP=no

[Network]
LinkLocalAddressing=no
DHCP=no
EOF

## enable systemd-resolve
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

## write all configs
cat <<EOF > /etc/systemd/resolved.conf
[Resolve]
FallbackDNS=
DNSStubListener=no
EOF

##############################################
## general
##############################################

cat <<EOF > /etc/ssh/sshd_config
Subsystem sftp internal-sftp
ClientAliveInterval 180
UseDNS no
PasswordAuthentication no
ChallengeResponseAuthentication no
EOF

##
## live image settings
## systemd configs from https://linux.xvx.cz/2017/07/how-to-build-pxe-fedora-26-live-image.html
## https://fedoraproject.org/wiki/LiveOS_image
##

cat <<EOF >> /etc/systemd/system.conf
DumpCore=no
EOF

cat <<EOF >> /etc/systemd/journald.conf
Storage=volatile
RuntimeMaxUse=15M
ForwardToSyslog=no
ForwardToConsole=no
EOF

## enable services
systemctl enable \
  systemd-networkd systemd-resolved \
  chronyd crond sshd

systemctl mask \
  NetworkManager \
  NetworkManager-wait-online \
  systemd-networkd-wait-online.service

## cleanup
dnf -y autoremove
dnf -y clean all

rm -f /etc/machine-id
touch /etc/machine-id

%end