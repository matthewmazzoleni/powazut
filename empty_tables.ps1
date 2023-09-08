# Login to Azure
Connect-AzAccount -UseDeviceAuthentication

# Select the subscription (if needed)
# Set-AzContext -SubscriptionId YOUR_SUBSCRIPTION_ID

# Define storage account and table details

$storageAccountName = "abesadiag01"
$tableName = "WADPerformanceCountersTable"
$accountKey = "62q00n+42JbFj99PeVJLp/MykPyOa35oHxf8t0ViS9koRVhbURA6HRTLYQrPW82PbkuTrSUncjuVDLblIYWAEw=="
$targetDate = "2023-08-01T00:00:00Z"

$context = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $accountKey

$table = Get-AzStorageTable -Name $tableName -Context $context

$count = 0;
$maxCount = 10000
$token = $null

do {
    # Get batch of entities with the desired Timestamp
    $entities = Get-AzTableRow -Table $table.CloudTable -CustomFilter "Timestamp gt datetime'$targetDate'"

    # Delete the entities
    $entities | ForEach-Object {
        Remove-AzTableRow -Table $tableName -Context $context -PartitionKey $_.PartitionKey -RowKey $_.RowKey -Force
    }

    $count = $count + $maxCount
    Write-Host "Cancellati: " + $count;

    # Get the continuation token for the next batch
    $token = Get-AzTableRowContinuationToken
} while ($token -ne $null)