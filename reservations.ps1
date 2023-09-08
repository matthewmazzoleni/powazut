

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

# get reservation info from csv (sigh)
$csvUrl = "https://isfratio.blob.core.windows.net/isfratio/ISFRatio.csv"
$csvResponse = Invoke-WebRequest -Uri $csvUrl -UseBasicParsing

# Get the content as bytes
$bytes = $csvResponse.Content

# Check for BOM (0xEF,0xBB,0xBF) and remove it if present
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $bytes = $bytes[3..($bytes.Length - 1)]
}

# Convert bytes to UTF-8 string
$csvString = [System.Text.Encoding]::UTF8.GetString($bytes)

# Convert the string to a PowerShell CSV object
$csvData = $csvString | ConvertFrom-Csv


# get vm

$vms = Get-AzVM

$results = @()

foreach ($vm in $vms) {

    $vmStatus = Get-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Status
    $vmPowerStatusDescription = "";

    foreach($vmPowerStatus in $vmStatus.Statuses){
        if($vmPowerStatus.Code -like "PowerState*") {
            $vmPowerStatusDescription = $vmPowerStatus.DisplayStatus
        }
    }

    if($vmPowerStatusDescription -ne "VM running") {
        break;
    }
    

    $InstanceSizeFlexibilityGroup = "N/A"
    $Ratio = "N/A"

    $csvRow = $csvData | Where-Object { $_.ArmSkuName -eq $vm.HardwareProfile.VMSize }

    if ($csvRow) {
        $InstanceSizeFlexibilityGroup = $csvRow.InstanceSizeFlexibilityGroup
        $Ratio = $csvRow.Ratio
    }

    $results += [PSCustomObject]@{
        "VM Name" = $vm.Name
        "vmPowerStatus" = $vmPowerStatusDescription
        "SkuName" = $vm.HardwareProfile.VMSize
        "InstanceSizeFlexibilityGroup" = $InstanceSizeFlexibilityGroup
        "UsedRatio" = $Ratio
    }
}

$results | Format-Table -AutoSize

$groupedResults = $results | Group-Object InstanceSizeFlexibilityGroup | Select-Object @{n='InstanceSizeFlexibilityGroup';e={$_.Group[0].InstanceSizeFlexibilityGroup}}, @{n='UsedRatio';e={($_.Group | Measure-Object UsedRatio -Sum).Sum}}

# Sort by SkuName and InstanceSizeFlexibilityGroup
$sortedGroupedResults = $groupedResults | Sort-Object InstanceSizeFlexibilityGroup

# Display the sorted grouped results
$sortedGroupedResults | Format-Table -AutoSize




# get reservations
$reservationOrders = Get-AzReservationOrder

$results = @()

foreach ($order in $reservationOrders) {

    $reservations = Get-AzReservation -OrderId $order.Name

    foreach ($reservation in $reservations) {
        
        if($reservation.ProvisioningState -ne "Succeeded") {
            continue;
        }
     
        $skuName = $reservation.SkuName
        
        $InstanceSizeFlexibilityGroup = "N/A"
        $Ratio = "N/A"

        $csvRow = $csvData | Where-Object { $_.ArmSkuName -eq $skuName }

        if ($csvRow) {
            $InstanceSizeFlexibilityGroup = $csvRow.InstanceSizeFlexibilityGroup
            $Ratio = $csvRow.Ratio
        }

        $results += [PSCustomObject]@{
            "SkuName" = $skuName
            "ProvisioningState" = "->" + $reservation.ProvisioningState + "<-"
            "InstanceSizeFlexibilityGroup" = $InstanceSizeFlexibilityGroup
            "PurchasedRatio" = $Ratio
        }
    }
}

$results | Format-Table -AutoSize

$groupedResults = $results | Group-Object InstanceSizeFlexibilityGroup | Select-Object @{n='InstanceSizeFlexibilityGroup';e={$_.Group[0].InstanceSizeFlexibilityGroup}}, @{n='PurchasedRatio';e={($_.Group | Measure-Object PurchasedRatio -Sum).Sum}}

# Sort by SkuName and InstanceSizeFlexibilityGroup
$sortedGroupedResults = $groupedResults | Sort-Object InstanceSizeFlexibilityGroup

# Display the sorted grouped results
$sortedGroupedResults | Format-Table -AutoSize


