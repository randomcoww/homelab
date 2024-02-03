locals {
  db_path             = "/data/users.db"
  base_path           = "/var/lib/lldap"
  config_path         = "${local.base_path}/lldap_config.toml"
  storage_secret_path = "${local.base_path}/private_key"
  ldaps_cert_path     = "${local.base_path}/cert.pem"
  ldaps_key_path      = "${local.base_path}/key.pem"
}

module "metadata" {
  source      = "../metadata"
  name        = var.name
  namespace   = var.namespace
  release     = var.release
  app_version = split(":", var.images.lldap)[1]
  manifests = {
    "templates/service.yaml"     = module.service.manifest
    "templates/ingress.yaml"     = module.ingress.manifest
    "templates/secret.yaml"      = module.secret.manifest
    "templates/statefulset.yaml" = module.statefulset.manifest
  }
}

module "secret" {
  source  = "../secret"
  name    = var.name
  app     = var.name
  release = var.release
  data = merge({
    ACCESS_KEY_ID     = var.s3_access_key_id
    SECRET_ACCESS_KEY = var.s3_secret_access_key
    storage-secret    = var.storage_secret
    "ldaps-cert.pem"  = chomp(tls_locally_signed_cert.lldap.cert_pem)
    "ldaps-key.pem"   = chomp(tls_private_key.lldap.private_key_pem)
    "config.toml"     = <<-EOF
    ## Default configuration for Docker.
    ## All the values can be overridden through environment variables, prefixed
    ## with "LLDAP_". For instance, "ldap_port" can be overridden with the
    ## "LLDAP_LDAP_PORT" variable.

    ## Tune the logging to be more verbose by setting this to be true.
    ## You can set it with the LLDAP_VERBOSE environment variable.
    verbose=true

    ## The host address that the LDAP server will be bound to.
    ## To enable IPv6 support, simply switch "ldap_host" to "::":
    ## To only allow connections from localhost (if you want to restrict to local self-hosted services),
    ## change it to "127.0.0.1" ("::1" in case of IPv6).
    ## If LLDAP server is running in docker, set it to "0.0.0.0" ("::" for IPv6) to allow connections
    ## originating from outside the container.
    ldap_host = "0.0.0.0"

    ## The port on which to have the LDAP server.
    ldap_port = ${var.ports.lldap}

    ## The host address that the HTTP server will be bound to.
    ## To enable IPv6 support, simply switch "http_host" to "::".
    ## To only allow connections from localhost (if you want to restrict to local self-hosted services),
    ## change it to "127.0.0.1" ("::1" in case of IPv6).
    ## If LLDAP server is running in docker, set it to "0.0.0.0" ("::" for IPv6) to allow connections
    ## originating from outside the container.
    http_host = "0.0.0.0"

    ## The port on which to have the HTTP server, for user login and
    ## administration.
    http_port = ${var.ports.lldap_http}

    ## The public URL of the server, for password reset links.
    http_url = "https://${var.service_hostname}"

    ## Random secret for JWT signature.
    ## This secret should be random, and should be shared with application
    ## servers that need to consume the JWTs.
    ## Changing this secret will invalidate all user sessions and require
    ## them to re-login.
    ## You should probably set it through the LLDAP_JWT_SECRET environment
    ## variable from a secret ".env" file.
    ## This can also be set from a file's contents by specifying the file path
    ## in the LLDAP_JWT_SECRET_FILE environment variable
    ## You can generate it with (on linux):
    ## LC_ALL=C tr -dc 'A-Za-z0-9!#%&'\''()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32; echo ''
    jwt_secret = "${var.jwt_token}"

    ## Base DN for LDAP.
    ## This is usually your domain name, and is used as a
    ## namespace for your users. The choice is arbitrary, but will be needed
    ## to configure the LDAP integration with other services.
    ## The sample value is for "example.com", but you can extend it with as
    ## many "dc" as you want, and you don't actually need to own the domain
    ## name.
    ldap_base_dn = "dc=${join(",dc=", slice(compact(split(".", var.service_hostname)), 1, length(compact(split(".", var.service_hostname)))))}"

    ## Admin username.
    ## For the LDAP interface, a value of "admin" here will create the LDAP
    ## user "cn=admin,ou=people,dc=example,dc=com" (with the base DN above).
    ## For the administration interface, this is the username.
    ldap_user_dn = "${var.admin_user}"

    ## Admin email.
    ## Email for the admin account. It is only used when initially creating
    ## the admin user, and can safely be omitted.
    #ldap_user_email = ""

    ## Admin password.
    ## Password for the admin account, both for the LDAP bind and for the
    ## administration interface. It is only used when initially creating
    ## the admin user.
    ## It should be minimum 8 characters long.
    ## You can set it with the LLDAP_LDAP_USER_PASS environment variable.
    ## This can also be set from a file's contents by specifying the file path
    ## in the LLDAP_LDAP_USER_PASS_FILE environment variable
    ## Note: you can create another admin user for user administration, this
    ## is just the default one.
    ldap_user_pass = "${var.admin_password}"

    ## Force reset of the admin password.
    ## Break glass in case of emergency: if you lost the admin password, you
    ## can set this to true to force a reset of the admin password to the value
    ## of ldap_user_pass above.
    force_reset_admin_password = true

    ## Database URL.
    ## This encodes the type of database (SQlite, MySQL, or PostgreSQL)
    ## , the path, the user, password, and sometimes the mode (when
    ## relevant).
    ## Note: SQlite should come with "?mode=rwc" to create the DB
    ## if not present.
    ## Example URLs:
    ##  - "postgres://postgres-user:password@postgres-server/my-database"
    ##  - "mysql://mysql-user:password@mysql-server/my-database"
    ##
    ## This can be overridden with the LLDAP_DATABASE_URL env variable.
    database_url = "sqlite://${local.db_path}?mode=rwc"

    ## Private key file.
    ## Not recommended, use key_seed instead.
    ## Contains the secret private key used to store the passwords safely.
    ## Note that even with a database dump and the private key, an attacker
    ## would still have to perform an (expensive) brute force attack to find
    ## each password.
    ## Randomly generated on first run if it doesn't exist.
    ## Env variable: LLDAP_KEY_FILE
    key_file = "${local.storage_secret_path}"

    ## Seed to generate the server private key, see key_file above.
    ## This can be any random string, the recommendation is that it's at least 12
    ## characters long.
    ## Env variable: LLDAP_KEY_SEED
    #key_seed = "RanD0m STR1ng"

    ## Ignored attributes.
    ## Some services will request attributes that are not present in LLDAP. When it
    ## is the case, LLDAP will warn about the attribute being unknown. If you want
    ## to ignore the attribute and the service works without, you can add it to this
    ## list to silence the warning.
    #ignored_user_attributes = [ "sAMAccountName" ]
    #ignored_group_attributes = [ "mail", "userPrincipalName" ]

    ## Options to configure SMTP parameters, to send password reset emails.
    ## To set these options from environment variables, use the following format
    ## (example with "password"): LLDAP_SMTP_OPTIONS__PASSWORD
    [smtp_options]
    ## Whether to enabled password reset via email, from LLDAP.
    enable_password_reset=true
    ## The SMTP server.
    server = "${var.smtp_host}"
    ## The SMTP port.
    port = ${var.smtp_port}
    ## How the connection is encrypted, either "NONE" (no encryption), "TLS" or "STARTTLS".
    smtp_encryption = "STARTTLS"
    ## The SMTP user, usually your email address.
    user = "${var.smtp_username}"
    ## The SMTP password.
    password = "${var.smtp_password}"
    ## The header field, optional: how the sender appears in the email. The first
    ## is a free-form name, followed by an email between <>.
    #from = "LLDAP Admin <sender@gmail.com>"
    ## Same for reply-to, optional.
    #reply_to = "Do not reply <noreply@localhost>"

    ## Options to configure LDAPS.
    ## To set these options from environment variables, use the following format
    ## (example with "port"): LLDAP_LDAPS_OPTIONS__PORT
    [ldaps_options]
    ## Whether to enable LDAPS.
    enabled = true
    ## Port on which to listen.
    port = ${var.ports.lldap_ldaps}
    ## Certificate file.
    cert_file = "${local.ldaps_cert_path}"
    ## Certificate key file.
    key_file = "${local.ldaps_key_path}"
    EOF
  })
}

module "service" {
  source  = "../service"
  name    = var.name
  app     = var.name
  release = var.release
  spec = {
    type = "ClusterIP"
    ports = [
      {
        name       = "ldaps"
        port       = var.ports.lldap_ldaps
        protocol   = "TCP"
        targetPort = var.ports.lldap_ldaps
      },
      {
        name       = "http"
        port       = var.ports.lldap_http
        protocol   = "TCP"
        targetPort = var.ports.lldap_http
      },
    ]
  }
}

module "ingress" {
  source             = "../ingress"
  name               = var.name
  app                = var.name
  release            = var.release
  ingress_class_name = var.ingress_class_name
  annotations        = var.nginx_ingress_annotations
  rules = [
    {
      host = var.service_hostname
      paths = [
        {
          service = var.name
          port    = var.ports.lldap_http
          path    = "/"
        }
      ]
    },
  ]
}

module "statefulset" {
  source   = "../statefulset"
  name     = var.name
  app      = var.name
  release  = var.release
  affinity = var.affinity
  replicas = 1
  annotations = {
    "checksum/secret" = sha256(module.secret.manifest)
  }
  spec = {
    initContainers = [
      {
        name  = "${var.name}-init"
        image = var.images.litestream
        args = [
          "restore",
          "-if-replica-exists",
          "-o",
          local.db_path,
          "s3://${var.s3_db_resource}",
        ]
        env = [
          {
            name = "LITESTREAM_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "LITESTREAM_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "lldap-data"
            mountPath = dirname(local.db_path)
          },
        ]
      }
    ]
    containers = [
      {
        name  = var.name
        image = var.images.lldap
        args = [
          "run",
          "-c",
          local.config_path,
        ]
        volumeMounts = [
          {
            name      = "lldap-data"
            mountPath = dirname(local.db_path)
          },
          {
            name      = "secret"
            mountPath = local.config_path
            subPath   = "config.toml"
          },
          {
            name      = "secret"
            mountPath = local.storage_secret_path
            subPath   = "storage-secret"
          },
          {
            name      = "secret"
            mountPath = local.ldaps_cert_path
            subPath   = "ldaps-cert.pem"
          },
          {
            name      = "secret"
            mountPath = local.ldaps_key_path
            subPath   = "ldaps-key.pem"
          },
        ]
      },
      {
        name  = "${var.name}-litestream"
        image = var.images.litestream
        args = [
          "replicate",
          local.db_path,
          "s3://${var.s3_db_resource}",
        ]
        env = [
          {
            name = "LITESTREAM_ACCESS_KEY_ID"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "ACCESS_KEY_ID"
              }
            }
          },
          {
            name = "LITESTREAM_SECRET_ACCESS_KEY"
            valueFrom = {
              secretKeyRef = {
                name = var.name
                key  = "SECRET_ACCESS_KEY"
              }
            }
          },
        ]
        volumeMounts = [
          {
            name      = "lldap-data"
            mountPath = dirname(local.db_path)
          },
        ]
      },
    ]
    volumes = [
      {
        name = "lldap-data"
        emptyDir = {
          medium = "Memory"
        }
      },
      {
        name = "secret"
        secret = {
          secretName = var.name
        }
      },
    ]
  }
}