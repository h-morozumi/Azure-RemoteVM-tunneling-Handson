@description('Name of the Virtual Machine.')
param name string

@description('Location for the resource.')
param location string

@description('Tags for the resource.')
param tags object = {}

@description('Subnet ID to deploy the VM into.')
param subnetId string

@description('Admin username for the VM.')
param adminUsername string

@secure()
@description('Admin password for the VM.')
param adminPassword string

@description('VM size.')
param vmSize string = 'Standard_B2s'

@description('OS image publisher.')
param imagePublisher string = 'Canonical'

@description('OS image offer.')
param imageOffer string = '0001-com-ubuntu-server-jammy'

@description('OS image SKU.')
param imageSku string = '22_04-lts-gen2'

// Cloud-init script to install and configure httpd on port 8080
var cloudInitScript = '''
#cloud-config
package_update: true
package_upgrade: true
packages:
  - apache2
runcmd:
  - sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
  - sed -i 's/:80/:8080/' /etc/apache2/sites-enabled/000-default.conf
  - systemctl restart apache2
  - systemctl enable apache2
'''

// NIC (private IP only, no public IP)
resource nic 'Microsoft.Network/networkInterfaces@2024-01-01' = {
  name: 'nic-${name}'
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

// Linux Virtual Machine
resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: take(name, 15)
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: base64(cloudInitScript)
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

output vmName string = vm.name
output vmId string = vm.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress
