#!/bin/bash

ignition_gen/ct < ignition_gen/container_linux_config.yml > ignition_gen/ignition.json


IGNITION_TRANSFORMED_FOR_PACKER=$(cat ignition_gen/ignition.json | sed 's,",\\",g' | sed 's,\\n,\\\\n,g')

cat > ignition_gen/ignition-packer-var.json << _EOF
{
  "ignition_config": "'${IGNITION_TRANSFORMED_FOR_PACKER}'"
}
_EOF