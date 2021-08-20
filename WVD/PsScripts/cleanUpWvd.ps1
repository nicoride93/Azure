#Modules required Az.Accounts, Az.Compute, Az.KeyVault, Az.DesktopVirtualization

#Variables
$subscriptionid="715a0462-0f46-49b1-98fc-4167715cb0b9"

$rgNotToCompare=@("RG_WVD_MGT_DWS")
$domain = "iamsabre.sabrenow.com"

$hps = Get-AzWvdHostPool -SubscriptionId $subscriptionid

#Get the information of all the session hosts inside all the hostpools and build an object
$getSessionHosts=@()
foreach($hp in $hps){
    $resourceGroup=$hp.Id.Split('/')[4]
    $hostpoolName=$hp.Name
    $getSessionHosts+=Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName
}

$sessionHosts = $getSessionHosts | Where-Object {$_.ResourceId.Split('/')[4] -notin $rgNotToCompare}

$vms = Get-AzVM | Where-Object {$_.ResourceGroupName -notin $rgNotToCompare}

$vmsToDelete=Compare-Object -ReferenceObject $vms.Id -DifferenceObject $sessionHosts.ResourceId

foreach ($vm in $vmsToDelete){
    if($vm.SideIndicator -eq "=>"){
        $vmId = $vm.InputObject
        $vmName=$vm.InputObject.Split('/')[8]
        #Check if the VM exists with the domain attached. 
        $hostpoolInfo = $sessionHosts | Where-Object ResourceId -EQ $vmId+"."+$domain
        #If does not exits with domain, search the VM alone.This case will work if the VM didnt complete the domain join process or is AAD joined. 
        if($hostpoolInfo -eq $null)
        {
            $hostpoolInfo = $sessionHosts | Where-Object ResourceId -EQ $vmId
        }
        $hostpoolName = $hostpoolInfo.Id.Split('/')[8]
        $hostpoolRg = $hostpoolInfo.Id.Split('/')[4]
        Write-Output "deleting $vmName from hostpool $hostpoolName and resource group $hostpoolRg"
        Remove-AzWvdSessionHost -HostPoolName $hostpoolName -Name $vmName -ResourceGroupName $hostpoolRg | Out-Null

    }
    else{
        #Delete resources
        $vmId = $vm.InputObject
        $vmName=$vm.InputObject.Split('/')[8]
        $VmInfo = $vms | Where-Object Id -EQ $vmId
        $nicName=$vmInfo.NetworkProfile.NetworkInterfaces.id.Split('/')[8]
        $diskName=$vmInfo.StorageProfile.OsDisk.Name
        Write-output("Deleting VM $vmName")
        Remove-AzVM -Name $vmInfo.Name -ResourceGroupName $vmInfo.ResourceGroupName -Force | Out-Null
        Remove-AzNetworkInterface -Name $nicName -ResourceGroupName $vmInfo.ResourceGroupName -Force | Out-Null
        Get-AzResource -Name $diskName -ResourceGroupName $vmInfo.ResourceGroupName | Remove-AzResource -force | Out-Null

    }
}




