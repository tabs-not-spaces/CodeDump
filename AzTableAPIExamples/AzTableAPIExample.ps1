#region params
$script:storageAccountName = ""
$script:storageAccountkey = "" #Account key - NOT connection string
$script:tableName = ""
#endregion
#region Functions
function New-AzTableHeader {
	param (
		[parameter(Mandatory = $false)]    
		$StorageAccountName = $script:storageAccountName,
		
		[parameter(Mandatory = $false)]
		$TableName = $script:tableName,
		
		[parameter(Mandatory = $false)]
		$StorageAccountkey = $script:storageAccountkey
	)
	$apiVersion = "2017-04-17"
	$GMTime = (Get-Date).ToUniversalTime().toString('R')
	$string = "$($GMTime)`n/$($storageAccountName)/$($tableName)"
	$hmacsha = New-Object System.Security.Cryptography.HMACSHA256
	$hmacsha.key = [Convert]::FromBase64String($storageAccountkey)
	$signature = $hmacsha.ComputeHash([Text.Encoding]::UTF8.GetBytes($string))
	$signature = [Convert]::ToBase64String($signature)
	@{    
		Authorization  = "SharedKeyLite " + $storageAccountName + ":" + $signature
		Accept         = "application/json;odata=fullmetadata"
		'x-ms-date'    = $GMTime
		"x-ms-version" = $apiVersion
	}
}
function Get-AzTableRowByRowKey {
	[cmdletbinding()]
	param (
		[parameter(Mandatory = $false)]    
		$StorageAccountName = $script:storageAccountName,
		[parameter(Mandatory = $false)]    
		$StorageAccountKey = $script:storageAccountkey,
		[parameter(Mandatory = $false)]    
		$TableName = $script:tableName,
		[parameter(Mandatory = $true)]
		$PartitionKey,
		[parameter(Mandatory = $true)]
		$RowKey
	)
	$headers = New-AzTableHeader -StorageAccountName $StorageAccountName -TableName $TableName -StorageAccountkey $StorageAccountKey
	$tableURL = "https://$($storageAccountName).table.core.windows.net/$($tableName)"
	$queryURL = "$($tableURL)?`$filter=(PartitionKey eq '$PartitionKey' and RowKey eq '$RowKey')"
	$item = Invoke-RestMethod -Method GET -Uri $queryURL -Headers $headers -ContentType 'application/json'
	$item.value
}
function Get-AzTableRowByPartitionKey {
	[cmdletbinding()]
	param (
		[parameter(Mandatory = $false)]    
		$StorageAccountName = $script:storageAccountName,
		[parameter(Mandatory = $false)]    
		$StorageAccountKey = $script:storageAccountkey,
		[parameter(Mandatory = $false)]    
		$TableName = $script:tableName,
		[parameter(Mandatory = $true)]
		$PartitionKey
	)
	$headers = New-AzTableHeader -StorageAccountName $StorageAccountName -TableName $TableName -StorageAccountkey $StorageAccountKey
	$tableURL = "https://$($storageAccountName).table.core.windows.net/$($tableName)"
	$queryURL = "$($tableURL)?`$filter=(PartitionKey eq '$PartitionKey')"
	$item = Invoke-RestMethod -Method GET -Uri $queryURL -Headers $headers -ContentType 'application/json'
	$item.value
}
function Merge-AzTableRow {
	[cmdletbinding()]
	param (
		[parameter(Mandatory = $false)]    
		$StorageAccount = $script:storageAccountName,
		[parameter(Mandatory = $false)]    
		$StorageKey = $script:storageAccountkey,
		[parameter(Mandatory = $false)]    
		$TableName = $script:tableName,
		[parameter(Mandatory = $true)]
		$PartitionKey,
		[parameter(Mandatory = $true)]
		$RowKey,
		[parameter(Mandatory = $true)]
		$Entity
	)
	$query = "$($TableName)(PartitionKey='$PartitionKey',RowKey='$Rowkey')"
	$queryURL = "https://$($storageAccountName).table.core.windows.net/$($query)"
	$headers = New-AzTableHeader -StorageAccountName $StorageAccountName -TableName $query -StorageAccountkey $StorageAccountKey
	$body = $Entity | ConvertTo-Json
	$item = Invoke-RestMethod -Method Merge -Uri $queryURL -Headers $headers -Body $body -ContentType 'application/json'
	$item
}
#endregion
#region Example entity
$entity = @{
	PropertyA = "ValueA"
	PropertyB = "ValueB"
	PropertyC = "ValueC"
	PropertyD = "ValueD"
	PropertyE = "ValueE"
}
#endregion
#region Example API calls
#add row to table (even if it exists)
Merge-AzTableRow -PartitionKey 'Example' -RowKey $entity.PropertyA -Entity $entity
	
#get all partition results
$items = Get-AzTableRowByPartitionKey -PartitionKey 'Example'

# get single row
$item = Get-AzTableRowByRowKey -PartitionKey 'Example' -RowKey $items[0].RowKey

#update / merge values to existing row
$change = @{PropertyE = "ValueChanged" }
Merge-AzTableRow -PartitionKey 'Example' -RowKey $item.PropertyA -Entity $change
#endregion