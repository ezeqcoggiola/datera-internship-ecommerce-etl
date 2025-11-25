#!/bin/bash

terraform destroy -auto-approve \
  -var "username=$1" \
  -var "dataset=$2" \
  -var "db_password=$3"
