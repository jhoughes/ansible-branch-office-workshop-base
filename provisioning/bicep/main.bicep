// =============================================================================
// main.bicep — One attendee's complete workshop lab
// =============================================================================
// Provisions a single attendee's lab environment in Azure. To deploy for all
// attendees, run deploy-all.sh which loops this template over the attendee
// list.
//
// This template is intentionally a single file (not modules). For a workshop
// lab where readability matters more than reusability, one file you can read
// top-to-bottom is better than seven you have to navigate.
//
// Resources created (per attendee):
//   - Virtual network and subnet
//   - Network security group (allows SSH from conference IPs only)
//   - Public IP for the control node
//   - Three NICs (only the control NIC has the public IP)
//   - Three VMs: control (Ubuntu), web1 (Ubuntu), mgmt1 (Windows Server 2022)
//   - Custom Script Extension on the Windows VM to bootstrap WinRM
//
// =============================================================================

// -----------------------------------------------------------------------------
// Parameters
// -----------------------------------------------------------------------------

@description('Two-digit attendee number, used in resource naming and IP allocation. Example: "07"')
@minLength(2)
@maxLength(2)
param attendeeNumber string

@description('Azure region. Default westus2 (Quincy, WA — closest to Seattle).')
param location string = 'westus2'

@description('Workshop name prefix. Used in resource naming.')
param workshopName string = 'workshop'

@description('SSH username for the Linux VMs.')
param sshUsername string = 'attendee'

@description('SSH password for the Linux VMs. Generate per-attendee in deploy-all.sh.')
@secure()
param sshPassword string

@description('Local administrator username for the Windows VM.')
param windowsAdminUsername string = 'workshop_admin'

@description('Local administrator password for the Windows VM. Generate per-attendee.')
@secure()
param windowsAdminPassword string

@description('CIDR blocks allowed inbound SSH to the control node. Default is wide open; tighten before workshop day.')
param allowedSshSources array = [
  '0.0.0.0/0'
]

@description('VM SKU for the Linux hosts.')
param vmSizeLinux string = 'Standard_B2s'

@description('VM SKU for the Windows host. Slightly bigger because Windows.')
param vmSizeWindows string = 'Standard_B2ms'

@description('URL of the WinRM bootstrap PowerShell script. Use a commit-pinned GitHub Gist raw URL — see provisioning/azure/roles/attendee-rg/defaults/main.yml for the recommended format.')
param winrmBootstrapScriptUrl string = 'https://gist.githubusercontent.com/jhoughes/7ec4aa531ad7dd8ce3a1453f89647da6/raw/5d6e07e60e84230b73dc76999a9b8ea5c4337485/winrm-bootstrap.ps1'

@description('cloud-init content for the control node, base64-encoded. Generate from cloud-init-control.yml in deploy-all.sh.')
param cloudInitBase64 string

@description('Workshop date for the delete_after tag. Format: YYYY-MM-DD')
param workshopDate string = '2026-12-31'

// -----------------------------------------------------------------------------
// Variables (computed from parameters)
// -----------------------------------------------------------------------------

var attendeeNum = int(attendeeNumber)

// IP allocation: each attendee gets a /16 vnet with their attendee number as
// the third octet. Attendee 07 = 10.7.0.0/16.
var vnetAddressSpace = '10.${attendeeNum}.0.0/16'
var subnetAddressSpace = '10.${attendeeNum}.0.0/24'
var controlPrivateIp = '10.${attendeeNum}.0.5'
var web1PrivateIp = '10.${attendeeNum}.0.10'
var mgmt1PrivateIp = '10.${attendeeNum}.0.20'

var commonTags = {
  workshop: 'branch-office-ansible'
  attendee: attendeeNumber
  managed_by: 'bicep-provisioning-template'
  delete_after: workshopDate
}

// -----------------------------------------------------------------------------
// Network: VNet, subnet, NSG
// -----------------------------------------------------------------------------

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: '${workshopName}-nsg'
  location: location
  tags: commonTags
  properties: {
    securityRules: [
      {
        name: 'AllowSshFromConference'
        properties: {
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefixes: allowedSshSources
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: '${workshopName}-vnet'
  location: location
  tags: commonTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressSpace
      ]
    }
    subnets: [
      {
        name: 'lab'
        properties: {
          addressPrefix: subnetAddressSpace
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// Public IP for the control node
// -----------------------------------------------------------------------------

resource controlPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'control-pip'
  location: location
  tags: commonTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// -----------------------------------------------------------------------------
// NICs: one per VM
// -----------------------------------------------------------------------------

resource controlNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'control-nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: controlPrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/lab'
          }
          publicIPAddress: {
            id: controlPip.id
          }
          primary: true
        }
      }
    ]
  }
}

resource web1Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'web1-nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: web1PrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/lab'
          }
          primary: true
        }
      }
    ]
  }
}

resource mgmt1Nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'mgmt1-nic'
  location: location
  tags: commonTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAddress: mgmt1PrivateIp
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: '${vnet.id}/subnets/lab'
          }
          primary: true
        }
      }
    ]
  }
}

// -----------------------------------------------------------------------------
// VMs
// -----------------------------------------------------------------------------

resource controlVm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'control'
  location: location
  tags: union(commonTags, { role: 'control' })
  properties: {
    hardwareProfile: {
      vmSize: vmSizeLinux
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'control-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'control'
      adminUsername: sshUsername
      adminPassword: sshPassword
      customData: cloudInitBase64
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: controlNic.id
        }
      ]
    }
  }
}

resource web1Vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'web1'
  location: location
  tags: union(commonTags, { role: 'web1' })
  properties: {
    hardwareProfile: {
      vmSize: vmSizeLinux
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        name: 'web1-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'web1'
      adminUsername: sshUsername
      adminPassword: sshPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: web1Nic.id
        }
      ]
    }
  }
}

resource mgmt1Vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: 'mgmt1'
  location: location
  tags: union(commonTags, { role: 'mgmt1' })
  properties: {
    hardwareProfile: {
      vmSize: vmSizeWindows
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-g2'
        version: 'latest'
      }
      osDisk: {
        name: 'mgmt1-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'mgmt1'
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: false
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: mgmt1Nic.id
        }
      ]
    }
  }
}

// -----------------------------------------------------------------------------
// WinRM bootstrap on the Windows VM via Custom Script Extension
// -----------------------------------------------------------------------------

resource winrmBootstrap 'Microsoft.Compute/virtualMachines/extensions@2024-03-01' = {
  parent: mgmt1Vm
  name: 'winrm-bootstrap'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        winrmBootstrapScriptUrl
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File winrm-bootstrap.ps1'
    }
  }
}

// -----------------------------------------------------------------------------
// Outputs (consumed by deploy-all.sh to build the credentials CSV)
// -----------------------------------------------------------------------------

output controlPublicIp string = controlPip.properties.ipAddress
output web1PrivateIp string = web1PrivateIp
output mgmt1PrivateIp string = mgmt1PrivateIp
output sshUsername string = sshUsername
output windowsAdminUsername string = windowsAdminUsername
