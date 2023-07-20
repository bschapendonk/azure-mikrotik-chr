param location string = resourceGroup().location
param name string
param tags object = {}

param adminUsername string
param adminKey string

param domainNameLabel string
param myIPAddress string
param subnetPrefix string

param vhd string

var privateIPAddress = cidrHost(subnetPrefix, 3)
var postfix = uniqueString(resourceGroup().id, name)

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: substring('${uniqueString(resourceGroup().id, 'Cloud Hosted Router')}${postfix}', 0, 24)
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-09-01' = {
  name: 'default'
  parent: storageAccount
}

resource container 'Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01' = {
  name: 'chr'
  parent: blobService
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-11-01' = {
  name: 'nsg-${name}-${postfix}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-Mikrotik-SSH'
        properties: {
          direction: 'Inbound'
          sourceAddressPrefix: myIPAddress
          sourcePortRange: '*'
          destinationAddressPrefix: privateIPAddress
          destinationPortRange: '22'
          protocol: 'Tcp'
          access: 'Allow'
          priority: 1001
          description: 'Allow Mikrotik SSH 22'
        }
      }
      {
        name: 'Allow-Mikrotik-Winbox'
        properties: {
          direction: 'Inbound'
          sourceAddressPrefix: myIPAddress
          sourcePortRange: '*'
          destinationAddressPrefix: privateIPAddress
          destinationPortRange: '8291'
          protocol: 'Tcp'
          access: 'Allow'
          priority: 1002
          description: 'Allow Mikrotik Winbox 8291'
        }
      }
    ]
  }
  tags: tags
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-11-01' = {
  name: 'vnet-${name}-${postfix}'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.9.20.0/24'
      ]
    }
    subnets: [
      {
        name: 'snet-${name}'
        properties: {
          addressPrefix: '10.9.20.0/24'
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
    ]
  }
  tags: tags
  resource subnet 'subnets' existing = {
    name: 'snet-${name}'
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2022-11-01' = {
  name: 'pip-${name}-${postfix}'
  location: location
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Dynamic'
    dnsSettings: {
      domainNameLabel: domainNameLabel
    }
  }
  tags: tags
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-11-01' = {
  name: 'nic-${name}-${postfix}'
  location: location
  properties: {
    enableIPForwarding: true
    networkSecurityGroup: {
      id: networkSecurityGroup.id
    }
    ipConfigurations: [
      {
        name: '${name}-${postfix}'
        properties: {
          subnet: {
            id: virtualNetwork::subnet.id
          }
          privateIPAddress: privateIPAddress
          privateIPAllocationMethod: 'Static'
          publicIPAddress: {
            id: publicIPAddress.id
          }
        }
      }
    ]
  }
  tags: tags
}

resource image 'Microsoft.Compute/images@2023-03-01' = {
  name: 'chr-7.10.2'
  location: location
  properties: {
    hyperVGeneration: 'V1'
    storageProfile: {
      osDisk: {
        osState: 'Generalized'
        osType: 'Linux'
        blobUri: '${reference(resourceId('Microsoft.Storage/storageAccounts', storageAccount.name)).primaryEndpoints.blob}${container.name}/${vhd}'
      }
    }
  }
  tags: tags
}

resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'vm-${name}-${postfix}'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    hardwareProfile: {
      vmSize: 'Standard_B1ls'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
          properties: {
            deleteOption: 'Delete'
          }
        }
      ]
    }
    osProfile: {
      computerName: '${name}-${postfix}'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              keyData: adminKey
              path: '/home/${adminUsername}/.ssh/authorized_keys'
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        id: image.id
      }
      osDisk: {
        name: 'disk-${name}-osdisk-${postfix}'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        deleteOption: 'Delete'
      }
    }

  }
  tags: tags
}
