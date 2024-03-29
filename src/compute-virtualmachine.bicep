// Parameters
//////////////////////////////////////////////////
@description('The Azure region of the resources.')
param location string

@description('Parameters specific to this module.')
param parameters object

@description('Tags to associate with the resources.')
param tags object

// Resources
//////////////////////////////////////////////////
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-09-01' existing = {
  name: parameters.virtualNetworkName
  resource virtualMachineSubnet 'subnets@2023-09-01' existing = {
    name: parameters.virtualMachineSubnetName
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' existing = {
  name: parameters.storageAccountName
}

resource postgresManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: parameters.postgresManagedIdentityName
}

resource virtualMachineNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: parameters.virtualMachineNicName
  tags: tags
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: virtualNetwork::virtualMachineSubnet.id
          }
        }
      }
    ]
  }
}

resource virtualMachines 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: parameters.virtualMachineName
  tags: tags
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v3'
    }
    osProfile: {
      computerName: parameters.virtualMachineName
      adminUsername: parameters.virtualMachineAdminUsername
      adminPassword: parameters.virtualMachineAdminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: '${parameters.virtualMachineOsDiskName}'
        caching: 'ReadWrite'
        createOption: 'FromImage'
        diskSizeGB: 50
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          caching: 'ReadWrite'
          diskSizeGB: 50
          lun: 1
          name: parameters.virtualMachineDataDiskName
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: virtualMachineNic.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${postgresManagedIdentity.id}': {}
    }
  }
}
