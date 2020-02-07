FROM golang:alpine AS MODULES

RUN set -x \
  \
  && apk add --no-cache \
    git \
    libvirt-dev \
    g++ \
  \
  && git clone https://github.com/randomcoww/terraform-provider-libvirt.git terraform-provider-libvirt \
  && cd terraform-provider-libvirt \
  && GO111MODULE=on GOOS=linux go install \
  && git clone https://github.com/poseidon/terraform-provider-matchbox.git terraform-provider-matchbox \
  && cd terraform-provider-matchbox \
  && GO111MODULE=on GOOS=linux go install

FROM golang:alpine AS MATCHBOX

RUN set -x \
  \
  && apk add --no-cache \
    git \
  \
  && git clone https://github.com/poseidon/matchbox.git matchbox \
  && cd matchbox/cmd/matchbox \
  && GO111MODULE=on GOOS=linux go install

FROM alpine:edge

ENV HOME /root
ENV VERSION 0.12.20

COPY --from=MATCHBOX /go/bin/ /usr/local/bin/
COPY files/tf-wrapper.sh /usr/local/bin/tf-wrapper
COPY files/start-renderer.sh /usr/local/bin/start-renderer

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
    https://releases.hashicorp.com/terraform/${VERSION}/terraform_${VERSION}_linux_amd64.zip \
  && unzip terraform.zip -d /usr/local/bin/ \
  && rm terraform.zip

WORKDIR $HOME
COPY --from=MODULES /go/bin/ go/bin/
COPY files/terraformrc .terraformrc
COPY files/ssh-config .ssh/config

VOLUME ["$HOME/mnt"]
WORKDIR $HOME/mnt/resourcesv2