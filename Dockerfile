FROM docker.io/golang:alpine AS MODULES

ARG SSH_VERSION
ARG SYNCTHING_VERSION

RUN set -x \
  \
  && apk add --no-cache \
    git \
    libvirt-dev \
    g++ \
  \
  && git clone -b v${SSH_VERSION} https://github.com/randomcoww/terraform-provider-ssh.git \
  && cd terraform-provider-ssh \
  && mkdir -p ${GOPATH}/bin/github.com/randomcoww/ssh/${SSH_VERSION}/linux_amd64 \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/randomcoww/ssh/${SSH_VERSION}/linux_amd64/terraform-provider-ssh_v${SSH_VERSION} \
  \
  && cd .. \
  && git clone -b v${SYNCTHING_VERSION} https://github.com/randomcoww/terraform-provider-syncthing.git \
  && cd terraform-provider-syncthing \
  && mkdir -p ${GOPATH}/bin/github.com/randomcoww/syncthing/${SYNCTHING_VERSION}/linux_amd64 \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/randomcoww/syncthing/${SYNCTHING_VERSION}/linux_amd64/terraform-provider-syncthing_v${SYNCTHING_VERSION}

FROM alpine:edge

ARG TF_VERSION

ENV HOME /root
WORKDIR $HOME

COPY --from=MODULES /go/bin/ .terraform.d/plugins/

RUN set -x \
  \
  && apk add --no-cache \
    bash \
    ca-certificates \
    libvirt-libs \
    openssh-client \
  \
  && update-ca-certificates \
  && wget -O terraform.zip \
    https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip \
  && unzip terraform.zip -d /usr/local/bin/ \
  && rm terraform.zip