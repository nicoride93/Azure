<#
.SYNOPSIS
    Clean up resources that are not attached to any Hostpool or exists in AVD but not as an Azure resource. 
.DESCRIPTION
    Modules required Az.Accounts, Az.Compute, Az.KeyVault, Az.DesktopVirtualization
    To start, please input the variables required to work
        subscriptionid: The subscription on where the AVD resources and VMs are
        rgNotToCompare: Resource groups that will be skipped on this process. If on the subscription we have another VMs running outsite of AVD, please input the RGs here
    After, the script will create an object with all the VMs that are part of the AVD as a session host. Will exclude all VMs in the rgNotToCompare variable. 
    Next, will create an object with all the VMs in the subscription. WIll exclude all VMs VMs in the rgNotToCompare variable. 
    Then will compare the objects, using the VM in the subscription as the main object and the session host object as a difference object. The result will be:
        VMs that are in the subcription but are not part of AVD as session hosts. '<='
        VMs that are in AVD as session hosts but the resources of that session hosts does not exist in Azure. '=>'
    At the end, will loop the object of differences and delete according to the status:
        If is in AVD, will remove the session host from AVD
        If the resource exits, will delete it and all the child resources (disk and network card)

.NOTES
    Author      : Nicolas Riderelli <nicolas.riderelli@microsoft.com>
    Source      : https://github.coom/nicoride93/Azure/tree/master/WVD/PsScripts
    Version     : 1.0.0
    SEE readme.md
#>

#Connect to Azure, using a account with priviledges to do the tasks that are required.
Connect-AzAccount

#Variables
#Subcription ID on where the script will run into
$subscriptionid="715a0462-0f46-49b1-98fc-4167715cb0b9"
#Array of resource groups that will be excluded.
$rgNotToCompare=@("RG_WVD_MGT_DWS")

#Get the information of all the session hosts inside all the hostpools and build an object
$hps = Get-AzWvdHostPool -SubscriptionId $subscriptionid
$getSessionHosts=@()
foreach($hp in $hps){
    $resourceGroup=$hp.Id.Split('/')[4]
    $hostpoolName=$hp.Name
    $getSessionHosts+=Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName | Where-Object {$_.ResourceId.Split('/')[4] -notin $rgNotToCompare}
}

#Get all BMs in the subcription, leaving behind the VMs in the resource groups excluded at the begining
$vms = Get-AzVM | Where-Object {$_.ResourceGroupName -notin $rgNotToCompare}

#Get the array of the VMs that we are going to delete. 
$vmsToDelete=Compare-Object -ReferenceObject $vms.Id -DifferenceObject $getSessionHosts.ResourceId

#Print the ammount of processes to do
$vmsDeleted = ($vmsToDelete | Where-Object SideIndicator -EQ "=>" | Measure-Object -Property SideIndicator ).Count
$vmsWithoutHostpool = ($vmsToDelete | Where-Object SideIndicator -EQ "<=" | Measure-Object -Property SideIndicator).Count 
Write-Output "Vms deleted but are in a hostpool: $vmsDeleted" 
Write-Output "Vms without a hostpool assigned: $vmsWithoutHostpool" 

#Foreach VM to be deleted, check if we need to remove it from AVD or remove the resources
foreach ($vm in $vmsToDelete){
    #Remove VM from AVD, since the VM resource does not exist
    if($vm.SideIndicator -eq "=>"){
        $vmId = $vm.InputObject
        $vmName=$vm.InputObject.Split('/')[8]
        $hostpoolInfo = $sessionHosts | Where-Object ResourceId -EQ $vmId
        $hostpoolName = $hostpoolInfo.Id.Split('/')[8]
        $hostpoolRg = $hostpoolInfo.Id.Split('/')[4]
        $vmFqdn = $hostpoolInfo.Id.Split('/')[10]
        Write-Output "deleting $vmName from hostpool $hostpoolName and resource group $hostpoolRg"
        Remove-AzWvdSessionHost -HostPoolName $hostpoolName -Name $vmFqdn -ResourceGroupName $hostpoolRg | Out-Null

    }
    else{
        #Delete the VM resources, since is not attached to any AVD hostpool
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