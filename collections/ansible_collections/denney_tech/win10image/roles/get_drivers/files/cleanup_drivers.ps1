[CmdletBinding()]
param (
    [String]
    $DownloadDir,
    [parameter(Mandatory=$true)]
    [validateset("HP","Dell","Lenovo","Panasonic","Microsoft")]
    [String]
    $Manufacturer
)
$Ansible.Changed = $false
function Invoke-HPDriverCleanup {
    param (
        [string]
        $DownloadDir="E:\DriverPacks\HP-Repository"
    )
    Set-Location "$DownloadDir"
    Invoke-RepositorySync -Quiet | Out-Null
    Invoke-RepositoryCleanup | Out-Null
    $Ansible.Changed = $true
}

function Invoke-LenovoDriverCleanup {
    param (
        [String]
        $DownloadDir="E:\DriverPacks\Lenovo-Repository"
    )
    $Date = [DateTime]::Today
    Get-ChildItem $DownloadDir | Foreach-Object {
        if (Test-Path "$($_.FullName)\LastUseDate.xml") {
            $lastusedate = Import-Clixml "$($_.FullName)\LastUseDate.xml"
            if ($date -gt $lastusedate) {
                Remove-Item $_.FullName -Recurse -Force
                $Ansible.Changed = $true
            }
        } else {
            Remove-Item $_.FullName -Recurse -Force
            $Ansible.Changed = $true
        }
    }
}

$invoke_args = @{
    ProdCode = $ProdCode
    Models = $Models
}
if ($DownloadDir) {
    $invoke_args.DownloadDir = $DownloadDir
}
if ($ExtractedDir) {
    $invoke_args.ExtractedDir = $ExtractedDir
}
if ($DeploymentShare) {
    $invoke_args.DeploymentShare = $DeploymentShare
}

switch ($Manufacturer) {
    "HP" {
        Import-Module HPCMSL
        Invoke-HPDriverCleanup @invoke_args
    }
    "Dell" {
        #Invoke-DellDriverCleanup @invoke_args
        Write-Warning "No Driver Automation for Dell implemented."
    }
    "Lenovo" {
        Invoke-LenovoDriverCleanup @invoke_args
    }
    "Panasonic" {
        #Invoke-PanasonicDriverCleanup @invoke_args
        Write-Warning "No Driver Automation for Panasonic implemented."
    }
    "Microsoft" {
        #Invoke-MicrosoftDriverCleanup @invoke_args
        Write-Warning "No Driver Automation for Microsoft implemented."
    }
}
