Get-AutomationConnection -Name 'AzureRunAsConnection' | out-null
Connect-AzAccount -ApplicationId "" -TenantId "" -Subscription "" -CertificateThumbprint "" | out-null

#Get all VMs in the subscription. This will be used to get the VM size
$allVms=Get-AzVM
#Get all disks in the subscription. This will be used to get the tier and the size of the disk
$allDisks=Get-AzDisk

$getsessionhosts = @()
#Getting all Hostpools that are personal
$getHostpools=Get-AzWvdHostPool -SubscriptionId 7c310ed5-60a5-4743-9b77-942c6af39177 | Where-Object HostPoolType -eq "Personal"
#Foreach hostpool get all sessions hosts 
foreach ($hostpool in $getHostpools){
    $resourceGroup=$hostpool.Id.Split('/')[4]
    $hostpoolName=$hostpool.Name
    $getSessionHosts+=Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName
}

#Get the billing period. Will always be the last month
$CURRENTDATE=GET-DATE -Hour 0 -Minute 0 -Second 0
$MonthAgo = $CURRENTDATE.AddMonths(-1)
$billingPeriod=GET-DATE $MonthAgo -Day 1 -Format yyyyMMdd
#Connect to the billing API and get the billing information for the VMs
$allBilling=Get-AzConsumptionUsageDetail -BillingPeriodName $billingPeriod | Where-Object InstanceId -like *Microsoft.Compute/virtualMachines*
#With the result, bild an object that holds the information of the VM and the total cost of the month
$vmCosts = ForEach ($vm in ($allBilling | Group Instancename))
{   [PSCustomObject]@{
        vmName = $vm.Name
        totalCost = ($vm.Group | Measure-Object pretaxcost -Sum).Sum
    }
}
#build the JSON
$vmObj = $null
$vmObj = @()
foreach ($session in $getSessionHosts){
    $vmName=$session.name.split('/')[1].split('.')[0]
    $totalCost=$vmCosts | Where-Object vmName -eq $vmName | Select -ExpandProperty totalCost
    $diskInfo=$allDisks | Where-Object ManagedBy -eq $session.ResourceId | Select Tier,DiskSizeGB
    $assignedUser=$session.AssignedUser
    $vmSize=($allVms | Where-Object Name -eq $vmName | select -ExpandProperty HardwareProfile).VmSize
    $vminfo = '' | Select AssignedUser,vmName,vmSize,cost,diskTier,diskGb
    $vminfo.assignedUser = $assignedUser
    $vminfo.vmName = $vmName
    $vminfo.vmSize = $vmSize
    $vminfo.cost = $totalCost
    $vminfo.diskTier = $diskInfo.Tier
    $vminfo.diskGb = $diskInfo.DiskSizeGB
    $vmObj += $vminfo
}

#Export the JSON so the LogicApp can transform it into a CSV and send it over email
Write-Output($vmObj | ConvertTo-Json)