#!/bin/bash

export AZURE_CORE_OUTPUT="yamlc"
export AZURE_DEFAULTS_LOCATION="westeurope"
export AZURE_DEFAULTS_GROUP="rg-mikrotik"

NAME="mikrotik-chr"

# FILE=.password
# [ ! -f $FILE ] && cat >$FILE <<EOF
# PASSWORD=$(echo $RANDOM | md5sum | head -c 12)
# EOF
# source $FILE

FILE=.domainNameLabel
[ ! -f $FILE ] && cat >$FILE <<EOF
DOMAIN_NAME_LABEL="$NAME-$(echo $RANDOM | md5sum | head -c 13)"
EOF
source $FILE

FILE=mikrotik.bicepparam
[ ! -f $FILE ] && cat >$FILE <<EOF
using 'mikrotik.bicep'

param name = '$NAME'

param adminUsername = '$USER'
param adminKey = '$(cat ~/.ssh/id_rsa.pub)'

param myIPAddress = '$(curl --silent ifconfig.me)'
param subnetPrefix = '10.9.20.0/24'
param domainNameLabel = '$DOMAIN_NAME_LABEL'

// download from https://mikrotik.com/download under the Cloud Hosted Router section
// choose the VirtualPC image
// then upload the unzipped file to the chr container in the storage account
param vhd = 'chr-7.10.2.vhd'
EOF

az group create --name $AZURE_DEFAULTS_GROUP
az group wait --created

az deployment group create \
    --template-file mikrotik.bicep \
    --parameters mikrotik.bicepparam
