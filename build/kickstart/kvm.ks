%include http://127.0.0.1:8080/generic?ks=live
%include http://127.0.0.1:8080/generic?ks=kvm

%post --erroronfail

## Add firmware for worker HBA passthrough
mkdir -p /etc/libvirt/boot

pushd /etc/libvirt/boot
curl -LO http://127.0.0.1:8080/assets/firmware/SAS9300_8i_IT.bin
popd

%end