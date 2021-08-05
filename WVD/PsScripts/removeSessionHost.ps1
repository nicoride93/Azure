#Modules required Az.Accounts, Az.Compute, Az.KeyVault, Az.DesktopVirtualization

#Variables

#Name of the KeyVault and the Secret that contains the joinDomain password
$vaultName='wvdAdvanceKickstarter'
$secretName='joinDomainPassword'

#Domain to which the VMs are joined. Must be with the . (dot) at the begining and the username of the account with priviledges to unjoin the machine 
$domain='.riderelli.com'
$User='RIDERELLI\GANDALF'

#Name, resource group and hostpool of the VM that we want to delete
$hostpool='west-us2-hp'
$vmName='westus-0'
$vmResourceGroup='nerdiodemo-rg'



#Connect to Azure using the RunAsAccount
Write-output("Connecting to Azure")
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
#Get VM info
Write-output("Getting VM Info")
$vmInfo=Get-AzVm -ResourceGroupName $vmResourceGroup -Name $vmName
$vmRg = $vmInfo.Id.Split('/')[4] 
$vmName=$vmInfo.Name

#Connect to Keyvault to get the Password
Write-output("Connecting to keyvault")
$secret=Get-AzKeyVaultSecret -vaultname $vaultName -Name $secretName -AsPlainText

#Set session host to drain mode
Write-output("Drain Mode on")
Update-AzWvdSessionHost -AllowNewSession:$false -HostPoolName $hostpool -ResourceGroupName $vmRg -Name ($vmName+$domain) | Out-Null

Start-Sleep -Seconds 30

#Run PS extension to unjoin the VM
Write-output("Checking if VM is running")
Start-AzVM -ResourceGroupName $vmResourceGroup -Name $vmName | Out-Null

Write-output("Unjoin VM from domain")
$scriptContent = @"
Param(
[parameter(Mandatory=`$true)][string]`$password
)
`$User = '$User'
`$securePassword = `$password | ConvertTo-SecureString -AsPlainText -Force
`$MyCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList `$User, `$securePassword
Remove-Computer -UnjoinDomainCredential `$MyCredential -Restart -Force
"@
Write-output("Running PS in the VM")
$execScriptName = 'Invoke-TempScript.ps1'
$execScriptPath = New-Item -Path $execScriptName -ItemType File -Force -Value $scriptContent | select -Expand FullName   
$invokeParams = @{
    VMName        = $vmName
    ResourceGroupName = $vmRg
    CommandId  = 'RunPowerShellScript'
    ScriptPath = $execScriptPath
    Parameter=@{password=$secret}
}
$result = Invoke-AzVMRunCommand @invokeParams

#Waiting 30 seconds for the VM to come back online
Start-Sleep -Seconds 30

#Remove from hostpool
Write-output("Removing VM from Hostpool")
Remove-AzWvdSessionHost -HostPoolName $hostpool -ResourceGroupName $vmRg -Name ($vmName+$domain) | Out-Null

#Delete resources
Write-output("Deleting resources")
$nicName=$vmInfo.NetworkProfile.NetworkInterfaces.id.Split('/')[8]
$diskName=$vmInfo.StorageProfile.OsDisk.Name
Remove-AzVM -Name $vmInfo.Name -ResourceGroupName $vmInfo.ResourceGroupName -Force | Out-Null
Remove-AzNetworkInterface -Name $nicName -ResourceGroupName $vmInfo.ResourceGroupName -Force | Out-Null
Get-AzResource -Name $diskName -ResourceGroupName $vmInfo.ResourceGroupName | Remove-AzResource -force | Out-Null

Write-output("VM deleted")