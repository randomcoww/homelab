### Generate renderer

```
terraform apply \
    -target=module.renderer \
    -target=local_file.ca_pem \
    -target=local_file.matchbox_private_key_pem \
    -target=local_file.matchbox_cert_pem 

docker run -it --rm \
    --user $(id -u):$(id -g) \
    -v "$(pwd)"/output/renderer:/etc/matchbox \
    -v "$(pwd)"/output/renderer:/var/lib/matchbox \
    -p 8080:8080 \
    -p 8081:8081 \
    quay.io/coreos/matchbox:latest \
        -data-path /var/lib/matchbox \
        -assets-path /var/lib/matchbox \
        -address 0.0.0.0:8080 \
        -rpc-address 0.0.0.0:8081
```

### Generate host kickstart (requires renderer)

```
terraform apply \
    -target=module.vm
```

### Generate provisioner ignition (requires renderer)

```
terraform apply \
    -target=module.provisioner
```

### Generate kubernetes ignition (requires provisioner)

```
terraform apply \
    -target=module.kubernetes_cluster \
    -target=local_file.admin_kubeconfig
```

### Generate desktop kickstart (requires provisioner)

```
terraform apply \
    -target=module.desktop
```

### Write out SSH CA key

```
terraform apply \
    -target=local_file.ssh_ca_key
```
