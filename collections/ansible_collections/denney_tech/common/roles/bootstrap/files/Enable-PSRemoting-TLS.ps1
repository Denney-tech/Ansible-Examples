
<#PSScriptInfo

.VERSION 1.0.2

.GUID 8012496c-2d3c-49d6-a8f3-d96592e84eef

.AUTHOR Denney_tech

.COMPANYNAME Denney.dev

.COPYRIGHT (c) Jan 16, 2021, Caleb Denney. All rights reserved.

.TAGS

.LICENSEURI

.PROJECTURI https://github.com/Denney-tech/Ansible/tree/main/collections/ansible_collections/denney_tech/common/roles/bootstrap/

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

<#

.DESCRIPTION
 Checkout Certificate from LDAP and Enable PSRemoting over HTTPS

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $fqdn,
    [Parameter(Mandatory=$true)]
    [string]
    $policyserver
)


$ansible.changed = $false

#Encountering some issues with $fqdn returning a null value or perhaps an array
#$fqdn = [System.Net.Dns]::GetHostByName($env:computerName).HostName
if (!($fqdn.split('.').count -ge 3)) {
    $ansible.failed = $true
    $ansible.result = "ansible_host is an invalid FQDN: $fqdn"
    exit
}

$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like "CN=$fqdn"
if ($cert.count -gt 1) {
    $ansible.failed = $true
    $ansible.result = "Multiple applicable certs found matching 'CN=$fqdn'."
    exit
}

##not 100% reliable, and unnecessary in our forest
#$caserver = (certutil | sls https).Line.split('//')[1].split('/')[0]
#$caDN = Get-ADComputer $caserver.split('.')[0] -Server (($caserver.split('.') | select -skip 1) -join '.')
#$policyserver = "ldap:///" + $caDN

$policyserver = "ldap:///CN=CA-server,OU=Servers,DC=contoso,DC=com"

if ($cert) {
    if ((Test-Certificate -Cert $cert) -and $cert.NotAfter -gt (Get-Date).AddDays(30)) {
        'Machine Certificate is good'
    } else {
        'Renewing Machine Certificate'
        certreq -Enroll -cert $cert.SerialNumber -machine -q -policyserver $policyserver Renew ReuseKeys
        $ansible.changed = $true
    }
} else {
    'Enrolling Machine Certificate'
    $cert = Get-Certificate -Template Machine -CertStoreLocation Cert:\LocalMachine\My -Url $policyserver -ErrorAction Stop
    $ansible.changed = $true
}

$cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -like "CN=$fqdn"
if ($cert.count -gt 1) {
    $ansible.failed = $true
    $ansible.result = "Multiple applicable certs found matching 'CN=$fqdn'."
    exit
}

$thumbprint = "$($($cert.Thumbprint -replace '(..)','$1 ').trim(' '))"
$ErrorActionCurrent = $ErrorActionPreference.ToString()
$ErrorActionPreference = "SilentlyContinue"
$config = Get-WSManInstance -ResourceURI bootstrap/config/listener -SelectorSet @{address="*";transport="https"} -ErrorAction SilentlyContinue
$ErrorActionPreference = $ErrorActionCurrent

#A lot of changes happen here to make sure we're in a ready state. Needs more work to become idempotent.
if ($config.enabled -notlike "true" -or $config.CertificateThumbprint -ne $thumbprint) {
    try {
        Set-WSManQuickConfig -SkipNetworkProfileCheck -UseSSL -Force -ErrorAction Stop
        $ansible.changed = $true
        Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
        $ansible.changed = $true
        Set-CertificateAutoEnrollmentPolicy -context machine -EnableAll -ErrorAction Stop
        $ansible.changed = $true
        Set-WSManInstance -ResourceURI bootstrap/config/listener -SelectorSet @{address="*";transport="https"} -ValueSet @{CertificateThumbprint="$($cert.Thumbprint)"} -ErrorAction Stop
        $ansible.changed = $true
    }
    catch{
        $ansible.failed = $true
        $ansible.result = $PSItem.Exception.Message
        exit
    }
} else {
    'PSRemoting over HTTPS Enabled'
}
