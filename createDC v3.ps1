# Logon
# add-azureaccount

# Get the Settings file

# Get-AzurePublishSettingsFile

#Import the file

Import-AzurePublishSettingsFile "C:\Data\AppZero\Azure\6-Month Plan (Windows Azure)-5-8-2015-credentials.publishsettings"

#get the Subscription details

Get-AzureSubscription


#Select the azure subsribtion
Select-AzureSubscription -Current "6-Month Plan (Windows Azure)" 

#set your storage account
Set-AzureSubscription -SubscriptionName "6-Month Plan (Windows Azure)" -CurrentStorageAccountName  "giostorage2"

# $AffinityGroup = ""
$cloudService = "AppzBootcamp"
$StorageAccount = "giostorage2"
$DNSIP = '10.0.0.4' #the first usable IP address in our Subnet "AD"
$VMName = 'DC1' #Name of the VM running our Domain Controller
$password = "Appz@123"
$username = "Appzero"

# set the Azure image to use
$image = Get-AzureVMImage | where { $_.ImageFamily -eq “Windows Server 2012 R2 Datacenter” } | Sort-Object -Descending -Property PublishedDate | Select-Object -First 1 -OutVariable image

#write-output $image


# Create New VM Configuration
    $newVM = New-AzureVMConfig -Name $VMName -InstanceSize Small -ImageName $image.ImageName -DiskLabel "OS" -HostCaching ReadOnly | Tee-Object -Variable NewVM


    $password = "Appz@123"
    $username = "Appzero"

    # Add password and username to config
     Add-AzureProvisioningConfig -Windows -Password $password -AdminUsername $username -VM $newVM


# set the AD Subnet for this machine
  Set-AzureSubnet -SubnetNames Subnet-1 -VM $newVM

#set the Static VNET IPAddress of 10.0.0.4 for our VM
  Set-AzureStaticVNetIP -IPAddress $DNSIP -VM $newVM 
  

# Create New VM with created config
New-AzureVM -ServiceName $cloudService -VMs $newVM -VNetName "AppzBootcamp1" -WaitForBoot   


#########################################################################################################################################


# enable WinRM to perform actinos on the VM
$WinRMCert = (Get-AzureVM -ServiceName $CloudService -Name $VMName | select -ExpandProperty vm).DefaultWinRMCertificateThumbprint
$AzureX509cert = Get-AzureCertificate -ServiceName $CloudService -Thumbprint $WinRMCert -ThumbprintAlgorithm sha1

$certTempFile = [IO.Path]::GetTempFileName()
$AzureX509cert.Data | Out-File $certTempFile

# Target The Cert That Needs To Be Imported
$CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "LocalMachine"
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
$store.Add($CertToImport)
$store.Close()

Remove-Item $certTempFile 


# Now use the Get-AzureWinrmUri
     $WinRMURi = (Get-AzureWinRMUri -ServiceName $cloudService -Name $VMName).AbsoluteUri

# Convert plain text password to secure string
$passwordsec = ConvertTo-SecureString -String $password -AsPlainText -Force

#create the Creds Object
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username,$passwordsec

# Open up a new PSSession to the Azure VM
$Session = New-PSSession -ConnectionUri $WinRMURi -Credential $cred

Invoke-Command -Session $Session -ArgumentList @($password) -ScriptBlock {
         Param ($password)
         # Set AD install paths
         $drive = "C"
         $NTDSpath = $drive + ":\Windows\NTDS"
         $SYSVOLpath = $drive + ":\Windows\SYSVOL"
         write-host "Installing the first DC in the domain"
         Install-WindowsFeature –Name AD-Domain-Services -includemanagementtools
         Install-ADDSForest -DatabasePath $NTDSpath -LogPath $NTDSpath -SysvolPath $SYSVOLpath -DomainName "Appzero.Local" -InstallDns -Force -Confirm:$True -safemodeadministratorpassword (convertto-securestring $password -asplaintext -force) 
     } 
