apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${kubernetes_ca_pem}
    server: ${kubernetes_apiserver_endpoint}
  name: ${kubernetes_cluster_name}
contexts:
- context:
    cluster: ${kubernetes_cluster_name}
    user: admin
  name: default
current-context: default
kind: Config
preferences: {}
users:
- name: admin
  user:
    as-user-extra: {}
    client-certificate-data: ${kubernetes_cert_pem}
    client-key-data: ${kubernetes_private_key_pem}