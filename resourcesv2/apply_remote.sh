#!/usr/bin/env bash

for i in `terraform state list |grep ".matchbox_profile."`; do
	terraform taint $i
done
terraform apply -auto-approve -var=renderer=$HOST
