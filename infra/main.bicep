@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention.')
param environmentName string

@description('Admin username for the Linux VM.')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for the Linux VM.')
param adminPassword string

@description('VM size for the Linux VM.')
param vmSize string = 'Standard_B2s'

var abbrs = loadJsonContent('abbreviations.json')
var location = resourceGroup().location
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = {
  'azd-env-name': environmentName
}

// Virtual Network with Subnets and NSGs
module vnet 'modules/vnet.bicep' = {
  name: 'vnet-deployment'
  params: {
    name: '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
  }
}

// Linux VM with httpd on port 8080
module vm 'modules/vm-linux.bicep' = {
  name: 'vm-deployment'
  params: {
    name: '${abbrs.computeVirtualMachines}${resourceToken}'
    location: location
    tags: tags
    subnetId: vnet.outputs.vmSubnetId
    adminUsername: adminUsername
    adminPassword: adminPassword
    vmSize: vmSize
  }
}

// Azure Bastion Standard
module bastion 'modules/bastion.bicep' = {
  name: 'bastion-deployment'
  params: {
    name: '${abbrs.networkBastionHosts}${resourceToken}'
    location: location
    tags: tags
    bastionSubnetId: vnet.outputs.bastionSubnetId
  }
}

output VNET_NAME string = vnet.outputs.vnetName
output VM_NAME string = vm.outputs.vmName
output VM_PRIVATE_IP string = vm.outputs.privateIpAddress
output BASTION_NAME string = bastion.outputs.bastionName
output RESOURCE_GROUP string = resourceGroup().name
output VM_RESOURCE_ID string = vm.outputs.vmId
output BASTION_TUNNEL_COMMAND string = 'az network bastion tunnel --name ${bastion.outputs.bastionName} --resource-group ${resourceGroup().name} --target-resource-id ${vm.outputs.vmId} --resource-port 8080 --port 8080'
