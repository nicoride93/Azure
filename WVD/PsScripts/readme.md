# PS Scripts that can help you

Here are some PS scripts that I have developed with the help of some other people. Are meant to help you manage the AVD infraestructure if they are run on Azure Automation accounts. 

|Script Name|Use|How to|Restrictions
|---|---|----|---|
| shutdownWVD.ps1 | This script is to shutdown VMs inside a personal hostpool. Can be adapted to pooled also. It will not shutdown VMs that has a 'noShutdown' tag (in case you want to skip that VM), that the creation time is less than 3 days (to give time to the VM to set up and download policies from the domain) and with active sessions. | Create an Azure Automation account and paste the code inside a new runbook. This script can be schedule to run every hour to evaluate the enviroment. Just enter the credentials to connect to the Azure tenant. | | 
| chargeBackPersonal.ps1 | (Personal VMs only) A lot of teams that are in charge of managing AVD strugles with the chargeback. This script is a help to help you navigate thought this chargeback. The script gets information from the Hostpool, VM, disks and the billing API, cross all the information and return a JSON file with the name of the person, the VM it uses and the cost of the month. | This script can be run as a standalone script but it will not export the data to anyother place than the output of the Azure Automation job that is running or the PS terminal that was invoke. That's why the best way to run this script is with a LogicApp that invokes the runbook and grabs the output and send it as an email to the team in charge. (An example on the LogicApp in a few weeks) | The account that is running the script needs access not only to the resources but also to the billing API as reader so it get the information. | 
| cloneImage.ps1 | When we are creating new AVD hostpools, we may need to create a new image into a SIG. This process can be slow if we don't know our way into the portal. For that, this PS Script can clone an image that already exists on the SIG and be our first version for that new image. | (More on how to use it on the following weeks) | |
| hostPoolManagement.ps1 | This script is part of a larger solution called AVD Advanced Kickstarter. Please refer to that documentation to learn more about this script | | | 
