Param 

(    
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 

    [String] 
    $sourceimagedef,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $name,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $imageManagedBy,
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()] 
    [String] 
    $ouPath
)
Get-AutomationConnection -Name 'AzureRunAsConnection' | out-null
Connect-AzAccount -ApplicationId "" -TenantId "" -Subscription "" -CertificateThumbprint "" | out-null


#Extract info of the ID of the source Image

$galleryRg=$sourceimagedef.Split('/')[4]
write-output($galleryRg)
$galleryName=$sourceimagedef.Split('/')[8]
write-output($galleryName)
$imageName=$sourceimagedef.Split('/')[10]
write-output($imageName)
#Get source image
$imageSource=Get-AzGalleryImageVersion -ResourceGroupName $galleryRg -GalleryName $galleryName -GalleryImageDefinitionName $imageName | Select-Object -Last 1
#Create new image defintion base on the source image
[hashtable]$tags += @{ImageManagedBy=$imageManagedBy;OuPath=$ouPath}
New-AzGalleryImageDefinition -GalleryName $galleryName -ResourceGroupName $galleryRg -Location $imageSource.location -Name $name -OsState Generalized -OsType Windows -HyperVGeneration v1 -Publisher 'Caterpillar' -Offer 'VDI' -Sku $name -Tag $tags


$region1=@{Name='East US';ReplicaCount=1}
$target = @($region1)
#Add first image version to that image definition
New-AzGalleryImageVersion -ResourceGroupName $galleryRg -GalleryName $galleryName -GalleryImageDefinitionName $name -Name 0.0.1 -Location $imageSource.location -ReplicaCount 1 -SourceImageId $imageSource.id -TargetRegion $target -asJob
