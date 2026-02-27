@description('Name of the Virtual Network.')
param name string

@description('Location for the resource.')
param location string

@description('Tags for the resource.')
param tags object = {}

@description('Address prefix for the Virtual Network.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Address prefix for the VM subnet.')
param vmSubnetAddressPrefix string = '10.0.1.0/24'

@description('Address prefix for the Azure Bastion subnet.')
param bastionSubnetAddressPrefix string = '10.0.0.0/26'

// NSG for VM Subnet - allow port 8080 inbound within VNet
resource vmSubnetNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-vm-subnet'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-8080-Inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
    ]
  }
}

// NSG for Azure Bastion Subnet (required rules)
resource bastionSubnetNsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: 'nsg-bastion-subnet'
  location: location
  tags: tags
  properties: {
    securityRules: [
      // Inbound rules
      {
        name: 'AllowHttpsInbound'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowGatewayManagerInbound'
        properties: {
          priority: 130
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowAzureLoadBalancerInbound'
        properties: {
          priority: 140
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowBastionHostCommunicationInbound'
        properties: {
          priority: 150
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      // Outbound rules
      {
        name: 'AllowSshRdpOutbound'
        properties: {
          priority: 100
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '22'
            '3389'
          ]
        }
      }
      {
        name: 'AllowAzureCloudOutbound'
        properties: {
          priority: 110
          direction: 'Outbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'AzureCloud'
          destinationPortRange: '443'
        }
      }
      {
        name: 'AllowBastionHostCommunicationOutbound'
        properties: {
          priority: 120
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: 'VirtualNetwork'
          destinationPortRanges: [
            '8080'
            '5701'
          ]
        }
      }
      {
        name: 'AllowGetSessionInformationOutbound'
        properties: {
          priority: 130
          direction: 'Outbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: 'Internet'
          destinationPortRanges: [
            '80'
            '443'
          ]
        }
      }
    ]
  }
}

// Virtual Network
resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-vm'
        properties: {
          addressPrefix: vmSubnetAddressPrefix
          networkSecurityGroup: {
            id: vmSubnetNsg.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
          networkSecurityGroup: {
            id: bastionSubnetNsg.id
          }
        }
      }
    ]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output vmSubnetId string = vnet.properties.subnets[0].id
output bastionSubnetId string = vnet.properties.subnets[1].id
