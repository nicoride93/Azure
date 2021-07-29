<#
PLEASE READ
The following script is to get the following information of the Personal Hostpools in Azure Virtual Desktop
1. Get a list of all my personal VMs that are assigned to a user. This list is going to be exported to CSV.
2. If a UPN is provided, it will look for the VM that is assigned to that user. 

BEFORE RUNNING THE SCRIPT, INPUT THE SUBSCRIPTION ID AND IF YOU NEED TO SEARCH FOR A USER, INPUT THE USER UPN
#>

#Connect to Azure with a read access Account
Connect-AzAccount

#The subscriptionId where the Hostpools are located. Must be inside the Azure tenant that we just connected
$subscriptionid=''

#The UPN of the user that we want to search. If none provided it will output a CSV with all the asigned session hosts
$upnToSearch=''

#Get all the hostpools in the subscription that are personal
$hps = Get-AzWvdHostPool -SubscriptionId $subscriptionid | Where-Object HostPoolType -eq "Personal"

#Get the information of all the session hosts inside all the hostpools and build an object
$getSessionHosts=@()
foreach($hp in $hps){
    $resourceGroup=$hp.Id.Split('/')[4]
    $hostpoolName=$hp.Name
    $getSessionHosts+=Get-AzWvdSessionHost -ResourceGroupName $resourceGroup -HostPoolName $hostpoolName
}

#If there is no UPN selected, create an array with Hostpool name, assigned user, VM name and VM full name (including domain)
if($upnToSearch -eq '') {
    $sessionObj=$null
    $sessionObj=@()
    #Iterate thought all the session hosts and build the object
    foreach($sessionHost in $getSessionHosts){
        #If the assigned user is emppty, skip
        if($sessionHost.AssignedUser -eq $null){
            Continue
        }
        $Hostpool=$sessionHost.Name.Split('/')[0]
        $AssignedUser=$sessionHost.AssignedUser
        $VmName=$sessionHost.Name.Split('/')[1].Split('.')[0]
        $FullVmName=$sessionHost.Name.Split('/')[1]
        $sessionInfo = '' | Select Hostpool,AssignedUser,VmName,FullVmName
        $sessionInfo.Hostpool = $Hostpool
        $sessionInfo.AssignedUser = $AssignedUser
        $sessionInfo.VmName = $VmName
        $sessionInfo.FullVmName = $FullVmName
        $sessionObj += $sessionInfo
    }
    #Export the object to a CSV in the temp folder in the C drive
    $sessionObj | Export-Csv C:\temp\users.csv
}
#If the UPN is provided, get the VM that is assigned to that user and show the information
else {
    $user=$getSessionHosts | Where-Object AssignedUser -eq $upnToSearch | select AssignedUser,Name
    $user
}
