FROM golang:alpine AS MODULES

ENV K8S_VERSION 0.1.0
ENV LIBVIRT_VERSION 0.1.0
ENV SSH_VERSION 0.1.1
ENV MATCHBOX_VERSION 0.3.0
ENV CT_VERSION 0.5.1

RUN set -x \
  \
  && apk add --no-cache \
    git \
    libvirt-dev \
    g++ \
  \
  ## Pull master but give it an arbitrary version because it is required
  && git clone https://github.com/hashicorp/terraform-provider-kubernetes-alpha.git \
  && cd terraform-provider-kubernetes-alpha \
  && mkdir -p ${GOPATH}/bin/github.com/hashicorp/kubernetes-alpha/${K8S_VERSION}/linux_amd64 \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/hashicorp/kubernetes-alpha/${K8S_VERSION}/linux_amd64/terraform-provider-kubernetes-alpha_v${K8S_VERSION} \
  \
  && cd .. \
  && git clone -b v${LIBVIRT_VERSION} https://github.com/randomcoww/terraform-provider-libvirt.git \
  && cd terraform-provider-libvirt \
  && mkdir -p ${GOPATH}/bin/github.com/randomcoww/libvirt/${LIBVIRT_VERSION}/linux_amd64 \
  && GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/randomcoww/libvirt/${LIBVIRT_VERSION}/linux_amd64/terraform-provider-libvirt_v${LIBVIRT_VERSION} \
  \
  && cd .. \
  && git clone -b v${SSH_VERSION} https://github.com/randomcoww/terraform-provider-ssh.git \
  && cd terraform-provider-ssh \
  && mkdir -p ${GOPATH}/bin/github.com/randomcoww/ssh/${SSH_VERSION}/linux_amd64 \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/randomcoww/ssh/${SSH_VERSION}/linux_amd64/terraform-provider-ssh_v${SSH_VERSION} \
  \
  ## Pull master but give it an arbitrary version because it is required
  && cd .. \
  && git clone https://github.com/poseidon/terraform-provider-matchbox.git \
  && cd terraform-provider-matchbox \
  && mkdir -p ${GOPATH}/bin/github.com/poseidon/matchbox/${MATCHBOX_VERSION}/linux_amd64 \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/poseidon/matchbox/${MATCHBOX_VERSION}/linux_amd64/terraform-provider-matchbox_v${MATCHBOX_VERSION} \
  \
  && cd .. \
  && git clone -b v${CT_VERSION} https://github.com/poseidon/terraform-provider-ct.git \
  && cd terraform-provider-ct \
  && mkdir -p ${GOPATH}/bin/github.com/poseidon/ct/${CT_VERSION}/linux_amd64 \
  && CGO_ENABLED=0 GO111MODULE=on GOOS=linux go build -v -ldflags '-s -w' \
    -o ${GOPATH}/bin/github.com/poseidon/ct/${CT_VERSION}/linux_amd64/terraform-provider-ct_v${CT_VERSION}

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

ENV TF_VERSION 0.13.0-beta3

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