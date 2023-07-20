# Azure Mikrotik Cloud Hosted Router
Basic Mikrotik Router OS CHR deploy to Azure using Bicep for learning/experimenting purposes.

## Requirements
* Azure Subscription
* Terminal using `bash` (WSL/Linux)
* Azure CLI
* Biceps installed `az bicep install`

## Usage
* Edit `mikrotik.sh` to change defaults if needed
    * Change `export AZURE_DEFAULTS_LOCATION="westeurope"` to change the default location
    * Change `export AZURE_DEFAULTS_GROUP="rg-mikrotik"` to change the default resource group name
    * Generates `mikrotik.bicepparam` if it does not exists, initial values can be changes in `mikrotik.sh`
    * Generates `.domainNameLabel` which contains the domainNameLabel for the VM
        * For example `mikrotik-chr-ad3038024aeaf`, then the fqdn will be `mikrotik-chr-ad3038024aeaf.westeurope.cloudapp.azure.com`
* Run `mikrotik.sh`
    * This wil create the resource group if it doesn't exists
    * Deplopy `mikrotik.bicep`
        * This will create a storage account
        * Create a Image from this storage account
        * Deploy a VM `Standard_B1ls` using this Image
    * It wil **fail on the deployment of `Microsoft.Compute/images`**, since there is no image uploaded yet
        * Please upload a CHR image of the type `VirtualPC image` which can be downloaded https://mikrotik.com/download to the `chr` container in the storage account and rerun `mikrotik.sh`
* By default the Network Security Group only exposes SSH and WinBox from the internet and only from the IP that ran `mikrotik.sh`.
    
