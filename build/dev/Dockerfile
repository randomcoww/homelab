FROM golang:alpine AS MODULES

ENV CT_VERSION v0.5.0

RUN set -x \
  \
  && apk add --no-cache \
    git \
    libvirt-dev \
    g++ \
  \
  && git clone https://github.com/hashicorp/terraform-provider-kubernetes-alpha.git \
  && cd terraform-provider-kubernetes-alpha \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go install -v -ldflags '-s -w' \
  \
  && cd .. \
  && git clone https://github.com/randomcoww/terraform-provider-libvirt.git \
  && cd terraform-provider-libvirt \
  && GO111MODULE=on GOOS=linux go install -v -ldflags '-s -w' \
  \
  && cd .. \
  && git clone https://github.com/randomcoww/terraform-provider-sshca.git \
  && cd terraform-provider-sshca \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go install -v -ldflags '-s -w' \
  \
  && cd .. \
  && git clone https://github.com/poseidon/terraform-provider-matchbox.git \
  && cd terraform-provider-matchbox \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go install -v -ldflags '-s -w' \
  \
  && cd .. \
  && git clone -b ${CT_VERSION} https://github.com/poseidon/terraform-provider-ct.git \
  && cd terraform-provider-ct \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
  -o ${GOPATH}/bin/terraform-provider-ct_${CT_VERSION}

FROM golang:alpine AS MATCHBOX

RUN set -x \
  \
  && apk add --no-cache \
    git \
  \
  && git clone https://github.com/poseidon/matchbox.git matchbox \
  && cd matchbox/cmd/matchbox \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go install -v -ldflags '-s -w'

FROM alpine:edge

ENV TF_VERSION 0.12.20

ENV HOME /root
WORKDIR $HOME

COPY --from=MATCHBOX /go/bin/ /usr/local/bin/
COPY files/tf-wrapper.sh /usr/local/bin/tf-wrapper
COPY files/start-renderer.sh /usr/local/bin/start-renderer
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