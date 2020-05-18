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
  \
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
ENV TF_VERSION 0.12.20
ENV CT_VERSION v0.5.0

WORKDIR $HOME

COPY --from=MATCHBOX /go/bin/ /usr/local/bin/
COPY files/tf-wrapper.sh /usr/local/bin/tf-wrapper
COPY files/start-renderer.sh /usr/local/bin/start-renderer
COPY --from=MODULES /go/bin/ .terraform.d/plugins/
COPY files/ssh-config .ssh/config

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
  && rm terraform.zip \
  \
  && wget -O terraform-provider-ct.tar.gz \
    https://github.com/poseidon/terraform-provider-ct/releases/download/${CT_VERSION}/terraform-provider-ct-${CT_VERSION}-linux-amd64.tar.gz \
  && tar xzf terraform-provider-ct.tar.gz --strip 1 -C .terraform.d/plugins/ \
  && rm terraform-provider-ct.tar.gz \
  && mv .terraform.d/plugins/terraform-provider-ct .terraform.d/plugins/terraform-provider-ct_${CT_VERSION}
