Param 
(    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $rgName, 
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $hpName,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [Int] 
    $deleteHP
) 
 
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         
 
    #"Logging in to Azure..."
    Connect-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-null
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        #Write-Error -Message $_.Exception
        #throw $_.Exception
    }
}
 
$token=New-AzWvdRegistrationInfo -ResourceGroupName $rgName -HostPoolName $hpName -ExpirationTime $((get-date).ToUniversalTime().AddDays(2).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))
 
$number=(Get-AzWvdSessionHost -HostPoolName $hpName -ResourceGroupName $rgName | Measure-Object Name).Count

$vmsInHostPool=Get-AzWvdSessionHost -HostPoolName $hpName -ResourceGroupName $rgName | select *
$rg=$vmsInHostPool[0].Id.Split('/')[4]
$prefix=$vmsInHostPool[0].Id.Split('/')[10].Split('.')[0].Split('-')[0]

if($deleteHP -eq 1){
    $vmsInHostPool=Get-AzWvdSessionHost -HostPoolName $hpName -ResourceGroupName $rgName
    foreach ($vm in $vmsInHostPool){
        $sessionhostname = $vm.Name.Split('/')[1]
        $vmName=$vm.Name.Split('/')[1].Split('.')[0]
        $vm=Get-AzVM -Name $vmName | select *
        $nicName=$vm.NetworkProfile.NetworkInterfaces.id.Split('/')[8]
        $diskName=$vm.StorageProfile.OsDisk.Name
        Remove-AzVM -Name $vm.Name -ResourceGroupName $vm.ResourceGroupName -Force | Out-Null
        Remove-AzNetworkInterface -Name $nicName -ResourceGroupName $vm.ResourceGroupName -Force | Out-Null
        Get-AzResource -Name $diskName -ResourceGroupName $vm.ResourceGroupName | Remove-AzResource -force | Out-Null
        Remove-AzWvdSessionHost -ResourceGroupName $rgName -HostPoolName $hpName -Name $sessionhostname | Out-Null
    }
}
 
write-output @{token=$token.Token;number=$number;rg=$rg;prefix=$prefix} | ConvertTo-Json