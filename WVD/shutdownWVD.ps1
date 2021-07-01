#Get-AutomationConnection -Name 'AzureRunAsConnection'
#Connect-AzAccount -ApplicationId "" -TenantId "" -Subscription "" -CertificateThumbprint ""

#Get all disks to get the information first
Write-Output ("Getting Disks")
$allDisks=Get-AzDisk

#Get all VMs to get the information first
Write-Output ("Getting VMs") 
$allVms=Get-AzVM

$getsessionhosts = @()
#Getting all Hostpools
$getHostpools=Get-AzWvdHostPool -SubscriptionId  | Where-Object HostPoolType -eq "Personal"
#Foreach hostpool get sessions hosts that are available and with no active session
foreach ($hostpool in $getHostpools){
    $resourceGroup=$hostpool.Id.Split('/')[4]
    $hostpoolName=$hostpool.Name
    Write-Output ("Getting VMs in HP {0}" -f $hostpoolName)  
    $getSessionHosts+=Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName | Where-Object {$_.Status -eq "Available" -and $_.Session -eq 0}
}
Write-Output ("-----------------------------")
Write-Output ("Evaluating {0} VMs to shutdown" -f $getSessionHosts.Count)

#Foreach VM in the session host array, see if we need to shutdown
foreach($sessionHost in $getSessionHosts){ 
    
    #Get basic information
    $hpName = $sessionHost.Id.Split('/')[8]
    $vmName = $sessionHost.ResourceId.Split('/')[8]
    $vmRg = $sessionHost.ResourceId.Split('/')[4]
    $tags=($allVms | Where-Object Name -eq $vmName | select -ExpandProperty tags).keys
    $vmCreationDate = ($allDisks | Where-Object ManagedBy -eq $sessionHost.ResourceId).TimeCreated

    Write-Output ("Working on VM {0}" -f $vmName)    
    #If the noShutdown tag exist, skip
    if ("noShutdown" -in $tags){
        Write-Output ("   noShutdown tag exists in {0}. Skipping" -f $vmName) 
        Continue
    }
    else
    {
        Write-Output ("   noShutdown tag does not exists in {0}" -f $vmName)
    }

    #If the VM was created less than 3 days ago, skip
    if($VMCreatedDate -ge (get-date).AddDays(-3))
    {
        Write-Output ("   VM {0} created less than 3 days ago. Skipping" -f $vmName) 
        Continue
    }
    else
    {
        Write-Output ("   VM {0} was created on date {1}" -f $vmName,(Get-Date $vmCreationDate -Format MM/dd/yyyy))
    }

    #Shutdown the VM. 
    Write-Output ("     Shutting down {0}" -f $vmName) 
    Stop-AzVM -Name $vmName -ResourceGroupName $vmRg -NoWait -Force -AsJob | Out-Null

}