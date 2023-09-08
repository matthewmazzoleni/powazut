

#precheck

#update powershell core: iex "& { $(irm https://aka.ms/install-powershell.ps1) } -UseMSI"


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

##################
#####TENANT#######
##################
$tenantOptions = Get-AzTenant
for ($i = 0; $i -lt $tenantOptions.Length; $i++) {
    Write-Host ("{0}: {1}" -f ($i + 1), $tenantOptions[$i].Name + " ( " + $tenantOptions[$i].Id +" )")
}

$tenantSelection = Read-Host "Seleziona il Tenant"
$TENANT_ID = $tenantOptions[[int]$tenantSelection - 1].Id

#Set-AzContext -SubscriptionId $SUBSCRIPTION_ID

###################
###SUBSCRIPTION####
###################
$subscriptionOptions = Get-AzSubscription -TenantId $TENANT_ID
for ($i = 0; $i -lt $subscriptionOptions.Length; $i++) {
    Write-Host ("{0}: {1}" -f ($i + 1), $subscriptionOptions[$i].Name + " ( " + $subscriptionOptions[$i].Id +" )")
}

$subscriptionSelection = Read-Host "Seleziona la sottoscrizione"
$SUBSCRIPTION_ID = $subscriptionOptions[[int]$subscriptionSelection - 1].Id


########################
###APP CONFIGURATION####
########################
$appServiceConfigOptions = ConvertFrom-Json (Get-Content -Raw -Path "appservice.config.json")
for ($i = 0; $i -lt $appServiceConfigOptions.Length; $i++) {
    Write-Host ("{0}: {1}" -f ($i + 1), $appServiceConfigOptions[$i].Name)
}

$appServiceConfigSelection = Read-Host "Seleziona il tipo di App Service"
$i = [int]$appServiceConfigSelection - 1

$RESOURCE_NAME_IDENTIFIER = $appServiceConfigOptions[$i].RESOURCE_NAME_IDENTIFIER
$VNET_RESOURCEGROUP = $appServiceConfigOptions[$i].VNET_RESOURCEGROUP
$VNET_NAME = $appServiceConfigOptions[$i].VNET_NAME
$SUBNET_NAME = $appServiceConfigOptions[$i].SUBNET_NAME
$RESOURCE_GROUP = $appServiceConfigOptions[$i].RESOURCE_GROUP
$LOCATION = $appServiceConfigOptions[$i].LOCATION
$LOCATION_SHORT = $appServiceConfigOptions[$i].LOCATION_SHORT
$APP_SERVICE_PLAN = $appServiceConfigOptions[$i].APP_SERVICE_PLAN
$RUNTIME = $appServiceConfigOptions[$i].RUNTIME
$HTTPS_ONLY = $appServiceConfigOptions[$i].HTTPS_ONLY
$FTP_STATE = $appServiceConfigOptions[$i].FTP_STATE
$MIN_TLS_VERSION = $appServiceConfigOptions[$i].MIN_TLS_VERSION
$HTTP2_ENABLED = $appServiceConfigOptions[$i].HTTP2_ENABLED
$VNET_ROUTEALL_ENABLED = $appServiceConfigOptions[$i].VNET_ROUTEALL_ENABLED
$ENVIRONMENT_TAG_VALUE = $appServiceConfigOptions[$i].ENVIRONMENT_TAG_VALUE

$PropertiesObject = @{
}

switch ($appServiceConfigOptions[$i].RUNTIME) {
    "v6.0" {
        $PropertiesObject["CURRENT_STACK"] = "dotnetcore"
    }
    default {
        # Code to execute when no case matches (optional)
    }
}

$SECURITY_GROUP_NAME = "grp_developer"
$ROLE = "Website Contributor"

##########################
###ASK INFO ABOUT APPN####
##########################

$isAClone = Read-Host "Serve clonare un'app esistente? (Y/N)"

if( $isAClone -eq "Y") {

    $sourceWebAppName = Read-Host "Qual'è il nome della WebApp di partenza?"

    $webAppOptions = Get-AzWebApp

    for ($i = 0; $i -lt $webAppOptions.Length; $i++) {
        if ($webAppOptions[$i].Name -like "*" + $sourceWebAppName + "*") {
            Write-Host ("{0}: {1}" -f ($i + 1), $webAppOptions[$i].Name + " - Kind: " + $webAppOptions[$i].Kind + " [ RG: " + $webAppOptions[$i].ResourceGroup +" ]")
        }
        
    }
    $webAppSelection = Read-Host "Seleziona la WebApp da clonare"
    $sourceWebApp = $webAppOptions[[int]$webAppSelection - 1]
}

$APPLICATION_CODE = Read-Host "Inserisci codice aziendale associato all'Applicativo"

$CUSTOMER_NAME = Read-Host "Inserisci nome Cliente"

$APPLICATION_NAME = Read-Host "Inserisci il nome all'applicativo"

$APPLICATION_TYPE = Read-Host "Inserisci tipo applicativo (es: web, api)"

$INSTANCE_NUMBER = Read-Host "Inserisci il numero di istanza (es: 001)"

$WEBAPP_NAME = $CUSTOMER_NAME + "-" + $APPLICATION_NAME + "-" + $RESOURCE_NAME_IDENTIFIER + "-" + $APPLICATION_TYPE + "-" + $LOCATION_SHORT + "-" + $INSTANCE_NUMBER




#########################

$vnet = Get-AzVirtualNetwork -ResourceGroupName $VNET_RESOURCEGROUP -Name $VNET_NAME
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $SUBNET_NAME -VirtualNetwork $vnet

# create the webapp
if( $isAClone -eq "Y") {
    $webApp = New-AzWebApp -ResourceGroupName $RESOURCE_GROUP -Name $WEBAPP_NAME -Location $LOCATION -AppServicePlan $APP_SERVICE_PLAN -SourceWebApp $sourceWebApp -IgnoreCustomHostNames -IgnoreSourceControl -IncludeSourceWebAppSlots
} else {
    $webApp = New-AzWebApp -ResourceGroupName $RESOURCE_GROUP -Name $WEBAPP_NAME -Location $LOCATION -AppServicePlan $APP_SERVICE_PLAN
}


# set configuration parameters
$webApp.HttpsOnly = $HTTPS_ONLY
#$webApp.SiteConfig.netFrameworkVersion = $RUNTIME
$webApp.SiteConfig.FtpsState = $FTP_STATE
$webApp.SiteConfig.MinTlsVersion = $MIN_TLS_VERSION
$webApp.SiteConfig.Http20Enabled = $HTTP2_ENABLED
$webApp.virtualNetworkSubnetId = $subnet.Id
$webApp.SiteConfig.VnetRouteAllEnabled = $VNET_ROUTEALL_ENABLED
$webApp | Set-AzWebApp

# tags
$tags = @{
            "Environment" = $ENVIRONMENT_TAG_VALUE
            "ApplicationCode" = $APPLICATION_CODE
        }
Update-AzTag -ResourceId $webApp.id -Tag $tags -Operation Merge

#set security
$SECURITY_GROUP_ID = (Get-AzADGroup -SearchString $SECURITY_GROUP_NAME).Id
$WEBAPP_ROLE = Get-AzRoleDefinition $ROLE
New-AzRoleAssignment -ObjectId $SECURITY_GROUP_ID -RoleDefinitionName $WEBAPP_ROLE.Name -Scope $webApp.Id



<#

************* ***************************************************** ***************************** *************************************** *****************************


Set-AzRouteConfig -Name "Route02" -AddressPrefix "AppService" -NextHopType "VirtualAppliance" -NextHopIpAddress "10.0.2.4"

$webAppOptions = Get-AzWebApp
for ($i = 0; $i -lt $webAppOptions.Length; $i++) {
    Write-Host ("{0}: {1}" -f ($i + 1), $webAppOptions[$i].Name + " ( RG: " + $webAppOptions[$i].ResourceGroup +" )")
}
$webAppSelection = Read-Host "Seleziona la WebApp da clonare"
$sourceWebApp = $webAppOptions[[int]$webAppSelection - 1]

$webApp = New-AzWebApp -ResourceGroupName $RESOURCE_GROUP -Name $APPLICATION_NAME -Location $LOCATION -AppServicePlan $APP_SERVICE_PLAN -SourceWebApp $sourceWebApp


$VNET_RESOURCEGROUP = "RG-PRIMARY"
$VNET_NAME = "VN-PRIMARY"
$SUBNET_NAME = "VN-APPSERVICECORE01-T-WESTEU"
$RESOURCE_GROUP = "RG-APPSERVICECORE01-T-WESTEU"
$LOCATION = "westeurope" # $locations = Get-AzLocation
$APP_SERVICE_PLAN = "abenergie-appservicecore01-t-westeu-win"
$APP_NAME = "abenergie-terminaldeploy-t-fa-westeu-001"
$STORAGE_NAME = "abterminaldeployt001"
#$RUNTIME = "dotnet:6.0"
$RUNTIME = "v6.0"
$FUNCTION_VERSION = 4
$STORAGE_SKU = "Standard_LRS"
$SUBNET_PATH = "/subscriptions/f89199ac-299b-4c27-8305-b393cd6a009a/resourceGroups/rg-primary/providers/Microsoft.Network/virtualNetworks/VN-PRIMARY/subnets/VN-APPSERVICECORE01-T-WESTEU"
$SUBNET_PATH = 
$SECURITY_GROUP_NAME = "grp_developer"
$ROLE = "Website Contributor"



/*******

$vnet = Get-AzVirtualNetwork -ResourceGroupName $VNET_RESOURCEGROUP -Name $VNET_NAME



enum EnvironmentTypeEnum {
    T
    D
    P
}


function createWebApp {
    param (
        [string]$AppName,
        [EnvironmentTypeEnum]$EnvironmentType
    )

    switch ($EnvironmentType) {
        EnvironmentTypeEnum:T {

        }
        EnvironmentTypeEnum:D {
            
        }
        EnvironmentTypeEnum:P {
            
        }
    }

    # create the WebApp
    $webApp = New-AzWebApp -ResourceGroupName $RESOURCE_GROUP -Name $APP_NAME -Location $LOCATION -AppServicePlan $APP_SERVICE_PLAN

    # configure default values
    $webApp.HttpsOnly = $true
    $webApp.SiteConfig.netFrameworkVersion = $RUNTIME
    $webApp.SiteConfig.FtpsState = "Disabled"
    $webApp.SiteConfig.MinTlsVersion = "1.2"
    $webApp.SiteConfig.Http20Enabled = $true
    $webApp.Properties.virtualNetworkSubnetId = $subnet.Id
    $webApp.Properties.vnetRouteAllEnabled = $true
    $webApp | Set-AzWebApp

    #set security
    $SECURITY_GROUP_ID = (Get-AzADGroup -SearchString $SECURITY_GROUP_NAME).Id
    $WEBAPP_ROLE = Get-AzRoleDefinition $ROLE
    New-AzRoleAssignment -ObjectId $SECURITY_GROUP_ID -RoleDefinitionName $WEBAPP_ROLE.Name -Scope $webApp.Id

    #vnet configuration
    $vnet = Get-AzVirtualNetwork -Name $VNET_NAME -ResourceGroupName $VNET_RESOURCEGROUP
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $SUBNET_NAME -VirtualNetwork $vnet
    $webAppResource = Get-AzResource -ResourceType "Microsoft.Web/sites" -ResourceGroupName $RESOURCE_GROUP -ResourceName $APP_NAME
    $webAppResource.Properties.virtualNetworkSubnetId = $subnet.Id
    $webAppResource.Properties.vnetRouteAllEnabled = $false
    $webAppResource | Set-AzResource -Force
}



*******/




Set-AzContext -SubscriptionId $SUBSCRIPTION_ID


#azure web app
$webApp = New-AzWebApp -ResourceGroupName $RESOURCE_GROUP -Name $APP_NAME -Location $LOCATION -AppServicePlan $APP_SERVICE_PLAN

#azure function app
$functionAppStorage = New-AzStorageAccount -Name $STORAGE_NAME -Location $LOCATION -ResourceGroupName $RESOURCE_GROUP -SkuName $STORAGE_SKU
$functionApp = New-AzFunctionApp -Name $APP_NAME -PlanName $APP_SERVICE_PLAN -ResourceGroupName $RESOURCE_GROUP -Runtime $RUNTIME -StorageAccountName $STORAGE_NAME -FunctionsVersion $FUNCTION_VERSION
$functionApp.Properties.virtualNetworkSubnetId = $subnetResourceId
$functionApp.Properties.vnetRouteAllEnabled = 'true'
$functionApp | Set-AzResource -Force





Set-AzWebApp -Name $APP_NAME -ResourceGroupName $RESOURCE_GROUP -AppServicePlan $APP_SERVICE_PLAN -VNetName $subnet.VnetName -VNetResourceGroupName $subnet.VnetResourceGroupName -VNetSubnetName $subnet.Name

Set-AzWebApp -ResourceGroupName $RESOURCE_GROUP -Name $APP_NAME -AppServicePlan $APP_SERVICE_PLAN -HttpsOnly $true -FtpsState "Disabled" -MinTlsVersion "1.2"

$SECURITY_GROUP_ID = (Get-AzADGroup -SearchString $SECURITY_GROUP_NAME).Id

$webAppRole = Get-AzRoleDefinition $ROLE

New-AzRoleAssignment -ObjectId $SECURITY_GROUP_ID -RoleDefinitionName $webAppRole.Name -Scope $webApp.Id




note:
$subnetResourceId = "/subscriptions/$vNetSubscriptionId/resourceGroups/$vNetResourceGroupName/providers/Microsoft.Network/virtualNetworks/$vNetName/subnets/$integrationSubnetName"
$webApp = Get-AzResource -ResourceType Microsoft.Web/sites -ResourceGroupName $webAppResourceGroupName -ResourceName $siteName
$webApp.Properties.virtualNetworkSubnetId = $subnetResourceId
$webApp.Properties.vnetRouteAllEnabled = 'true'
$webApp | Set-AzResource -Force


-----------------


SUBSCRIPTION_ID="f89199ac-299b-4c27-8305-b393cd6a009a" # ABenergie Subscription: Microsoft Azure
RESOURCE_GROUP="RG-APPSERVICECORE01-T-WESTEU"
LOCATION="WESTEU"
APP_SERVICE_PLAN="abenergie-appservicecore01-t-westeu-win"
APP_NAME="abenergie-listini-t-api-westeu-002" # dinamico
RUNTIME="dotnet:6"
SUBNET_PATH="/subscriptions/f89199ac-299b-4c27-8305-b393cd6a009a/resourceGroups/rg-primary/providers/Microsoft.Network/virtualNetworks/VN-PRIMARY/subnets/VN-APPSERVICECORE01-T-WESTEU" # VN-APPSERVICECORE01-T-WESTEU
SECURITY_GROUP_NAME="grp_developer"
ROLE="Website Contributor"
SECURITY_GROUP_ID=$(az ad group show --g $SECURITY_GROUP_NAME --query id -o tsv)
APP_RESOURCE_ID=$(az webapp show --name $APP_NAME --resource-group $RESOURCE_GROUP --query id -o tsv)

az account set --subscription $SUBSCRIPTION_ID
az webapp create --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN --name $APP_NAME --https-only true --subnet $SUBNET_PATH --runtime $RUNTIME
az webapp config set --name $APP_NAME --resource-group $RESOURCE_GROUP --vnet-route-all-enabled false  --ftps-state "Disabled"
az role assignment create --assignee-object-id $SECURITY_GROUP_ID --role "$ROLE" --scope $APP_RESOURCE_ID --assignee-principal-type Group

#>