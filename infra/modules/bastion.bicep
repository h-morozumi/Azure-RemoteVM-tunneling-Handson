@description('Name of the Bastion Host.')
param name string

@description('Location for the resource.')
param location string

@description('Tags for the resource.')
param tags object = {}

@description('Subnet ID for the AzureBastionSubnet.')
param bastionSubnetId string

// Public IP for Bastion
resource bastionPip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: 'pip-${name}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Bastion (Standard SKU)
resource bastion 'Microsoft.Network/bastionHosts@2024-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    enableTunneling: true
    ipConfigurations: [
      {
        name: 'bastion-ipconfig'
        properties: {
          subnet: {
            id: bastionSubnetId
          }
          publicIPAddress: {
            id: bastionPip.id
          }
        }
      }
    ]
  }
}

output bastionName string = bastion.name
output bastionId string = bastion.id
