#!/bin/bash

# Copyright 2023, Bloomberg Finance L.P.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

# http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -xe

cd "$(dirname "$(dirname "$0")")"
os_config_variables="config/variables.json"
s3_variables="config/s3.json"

# Check if an official base box is added to vagrant
S3_CONFIG_FILE=$(jq -r '.s3_config_file' "$s3_variables")
BUCKET=$(jq -r '.bucket' "$s3_variables")

if [ "$BUCKET" == "null" ]; then
    printf "One or more variables in %s are undefined.\n" "$s3_variables"
    exit 1
fi

if [ -z "${VAGRANT_DEFAULT_PROVIDER}" ]; then
    echo "VAGRANT_DEFAULT_PROVIDER is not defined"
    exit 1
fi

for OS_RELEASE in $(jq -r '. | keys[]' "${os_config_variables}"); do
    OS_RELEASE_AND_PROVIDER="${OS_RELEASE}_${VAGRANT_DEFAULT_PROVIDER}"

    # Generate configuration variables for this OS release
    PACKER_BOX_NAME=$(jq -r ".[\"${OS_RELEASE}\"].output_packer_box_name" \
        "${os_config_variables}")

    # Download base box from s3 storage
    mkdir -p "output-vagrant-${OS_RELEASE}"

    if [ "$S3_CONFIG_FILE" == "null" ]; then
        s3cmd get --force \
            "${BUCKET}/bcc-ubuntu-${OS_RELEASE_AND_PROVIDER}.box" \
            "output-vagrant-${OS_RELEASE}/package.box"
    else
        s3cmd -c "${S3_CONFIG_FILE}" get --force \
            "${BUCKET}/bcc-ubuntu-${OS_RELEASE_AND_PROVIDER}.box" \
            "output-vagrant-${OS_RELEASE}/package.box"
    fi

    # add the downloaded box as the output box in vagrant
    VAGRANT_VAGRANTFILE=Vagrantfile vagrant box add \
                        --force \
                        --clean \
                        --name "$PACKER_BOX_NAME" \
                        "file://output-vagrant-${OS_RELEASE}/package.box"
done
