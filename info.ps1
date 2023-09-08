

$moduleNames = @("Microsoft.Graph", "Az")
foreach ($moduleName in $moduleNames) {
    $moduleInstalled = Get-Module -ListAvailable | Where-Object { $_.Name -eq $moduleName }


    if (-not $moduleInstalled) {
        Write-Host "The module '$moduleName' is NOT installed."
        return  # Stop the script
    } else {
        $latestVersion = Find-Module -Name $moduleName | Sort-Object Version -Descending | Select-Object -First 1
        $installedVersion = (Get-InstalledModule -Name $moduleName).Version

        if ($installedVersion -lt $latestVersion.Version) {
            Write-Host "A newer version ($($latestVersion.Version)) of $($moduleName) is available. Installed version is $($installedVersion)."
        }
    }
}


Connect-AzAccount -UseDeviceAuthentication

# Create an array to store app service information
$appServiceInfo = @()

# Get all app services
$appServices = Get-AzWebApp

$rowCounter = 0

foreach ($appService in $appServices) {
  $vnetName = $null
  $vnetAddress = $null

  # Check if VNet integration is present
  $vnetIntegration = $appService.virtualNetworkSubnetId
  if ($vnetIntegration) {
    # Fetch the VNet info using the Swift virtual network connection string
    
    $subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $vnetIntegration
    if ($subnet) {
      $vnetName = $subnet.Name
      $vnetAddress = $subnet.AddressPrefix
    }
  }

  $rowCounter++

  $appServiceInfo += [PSCustomObject]@{
    "Counter"           = $rowCounter.ToString().PadLeft(5,'0')
    "App Service Name"  = $appService.Name
    "App State"         = $appService.State
    "VNet Name"         = $vnetName
    "VNet Address"      = $vnetAddress
  }

  #get slots
  $webAppSlots = Get-AzWebAppSlot -Name $appService.Name -ResourceGroupName $appService.ResourceGroup -ErrorAction SilentlyContinue

  foreach ($WebAppSlot in $WebAppSlots) {

    $vnetIntegration = $WebAppSlot.virtualNetworkSubnetId
    if ($vnetIntegration) {
        # Fetch the VNet info using the Swift virtual network connection string

        $subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $vnetIntegration
            if ($subnet) {
                $vnetName = $subnet.Name
                $vnetAddress = $subnet.AddressPrefix
            }
    }

    $rowCounter++

    $appServiceInfo += [PSCustomObject]@{
        "Counter"           = $rowCounter.ToString().PadLeft(5,'0')
        "App Service Name"  = " ╚══ " + $WebAppSlot.Name.replace($appService.Name,'')
        "App State"         = $WebAppSlot.State
        "VNet Name"         = $vnetName
        "VNet Address"      = $vnetAddress
      }
  }

}

# Display the information as a table, sorted by App Service Name
$appServiceInfo | Sort-Object "Counter" | Format-Table -AutoSize



$vms = Get-AzVM

$vmServiceInfo = @()

foreach ($vm in $vms) {
    
    $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    $vmPowerStatusDescription = "";

    foreach($vmPowerStatus in $vmStatus.Statuses){
        if($vmPowerStatus.Code -like "PowerState*") {
            $vmPowerStatusDescription = $vmPowerStatus.DisplayStatus
        }
    }

    foreach($networkInterfaceInfo in $vm.networkProfile.networkInterfaces){
        $networkInterface = Get-AzNetworkInterface -ResourceId $networkInterfaceInfo.Id

        foreach($ipConfiguration in $networkInterface.IpConfigurations){
            
            $subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $ipConfiguration.Subnet.Id
            $vnetName = $subnet.Name
            $vnetAddress = $subnet.AddressPrefix

            $vmServiceInfo += [PSCustomObject]@{
                "VM Name"       = $vm.Name
                "VM Size"       = $vm.hardwareProfile.VmSize
                "VM PowerState" = $vmPowerStatusDescription
                "VM IP"         = $ipConfiguration.PrivateIpAddress
                "VNet Name"     = $vnetName
                "VNet Address"  = $vnetAddress
                }

        }
    }
}

$vmServiceInfo | Sort-Object "VNet Name", "VM Name" | Format-Table


################# EMPTY RESOURCE GROUP

# Get all resource groups
$resourceGroups = Get-AzResourceGroup

# Create an empty array to hold empty resource groups
$emptyResourceGroups = @()

foreach ($rg in $resourceGroups) {
    # Check if the resource group is empty
    $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName
    if (-not $resources) {
        $emptyResourceGroups += $rg
    }
}

# Display empty resource groups
$emptyResourceGroups | Format-Table -Property ResourceGroupName, Location



