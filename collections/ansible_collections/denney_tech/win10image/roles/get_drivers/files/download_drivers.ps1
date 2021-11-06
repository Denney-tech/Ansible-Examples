[CmdletBinding()]
param (
    [String]
    $DownloadDir,
    [String]
    $ExtractedDir,
    [String]
    $DeploymentShare="C:\Imaging\MDTUSB",
    [String[]]
    $ProdCode,
    [String[]]
    $Models,
    [parameter(Mandatory=$true)]
    [validateset("HP","Dell","Lenovo","Panasonic","Microsoft")]
    [String]
    $Manufacturer
)

$Verbose = @{
    Verbose = $false
}

$Ansible.Changed = $false

$winver = "21H1" # this is just for messages, not a command variable

function Invoke-HPDriverDownload {
    param(
        [String]
        $DownloadDir="E:\DriverPacks\HP-Repository",
        [String]
        $ExtractedDir="E:\DriverPacks\Extracted",
        [String]
        $DeploymentShare="C:\Imaging\MDTUSB",
        [String]
        $ProdCode,
        [String[]]
        $Models
    )
    $OSVERs = @(
        @{Os = 'win10'; OsVer = "21H1" }
        @{Os = 'win10'; OsVer = "2009" }
        @{Os = 'win10'; OsVer = "2004" }
        @{Os = 'win10'; OsVer = "1909" }
        @{Os = 'win10'; OsVer = "1903" }
        @{Os = 'win10'; OsVer = "1809" }
        @{Os = 'win10'; OsVer = "1803" }
        @{Os = 'win10'; OsVer = "1709" }
        @{Os = 'win10'; OsVer = "1703" }
        @{Os = 'win10'; OsVer = "1607" }
        @{Os = 'win10'; OsVer = "1511" }
        @{Os = 'win10'; OsVer = "1507" }
        @{Os = 'win8.1'; OsVer = $null }
        @{Os = 'win8'; OsVer = $null }
        @{Os = 'win7'; OsVer = $null }
    )

    if (!(Test-Path $DownloadDir)) {
        New-Item -Path $DownloadDir -ItemType Directory -Force @Verbose
        $Ansible.Changed = $true; Write-Output "Changed 1"
    }
    Set-Location "$DownloadDir"
    if (Get-RepositoryInfo -ErrorAction SilentlyContinue) {
        #Inventory exists
    } else {
        Initialize-Repository @Verbose
        $Ansible.Changed = $true; Write-Output "Changed 2"
    }

    $SoftPaq = @()
    $i = 0
    While ([String]::IsNullorEmpty($SoftPaq)) {
        if ($null -eq $OSVERs.Os[$i]) {
            $SoftPaq = "No DriverPacks found for $ProdCode on any supported version of Windows from Win7 up to Win10 $winver."
            Remove-RepositoryFilter -Platform $ProdCode -Yes @Verbose
            Write-Output "$SoftPaq"
        } else {
            if ($null -eq $OSVERs.OsVer[$i]) {
                $SoftPaqParams = @{
                    Category = 'DriverPack'
                    Platform = $ProdCode
                    Os = $OSVERs.Os[$i]
                }
                $operatingSystem = $SoftPaqParams.Os
            } else {
                $SoftPaqParams = @{
                    Category = 'DriverPack'
                    Platform = $ProdCode
                    Os = $OSVers.Os[$i]
                    OsVer = $OSVers.OsVer[$i]
                }
                $operatingSystem = $SoftPaqParams.Os,$SoftPaqParams.OsVer -join ':'
            }
            $SoftPaq = Get-SoftpaqList @SoftPaqParams -Quiet -ErrorAction SilentlyContinue @Verbose
            if ($SoftPaq) {
                $info = Get-RepositoryInfo | Select-Object -ExpandProperty Filters | Where-Object {$_.platform -like $ProdCode}
                if ($info) {
                    if ($info.operatingSystem -notlike ($operatingSystem)) {
                        Remove-RepositoryFilter -Platform $ProdCode -Yes @Verbose
                        Add-RepositoryFilter @SoftPaqParams -ErrorAction SilentlyContinue @Verbose
                        $Ansible.Changed = $true; Write-Output "Changed 3"
                    }
                } else {
                    Add-RepositoryFilter @SoftPaqParams -ErrorAction SilentlyContinue @Verbose
                    $Ansible.Changed = $true; Write-Output "Changed 4"
                }
            }
            $i++
        }
    }

    $DriverPack = $SoftPaq | Where-Object { $_.category -eq 'Manageability - Driver Pack' }
    $DriverPack = $DriverPack | Where-Object { $_.Name -notlike "*Windows*PE*" }
    $DriverPack = $DriverPack | Where-Object { $_.Name -notlike "*WinPE*" }


    if ($DriverPack) {
        $DownloadDriverPackRootArchiveFullPath = "$($DownloadDir)"
        $SaveAs = "$($DownloadDriverPackRootArchiveFullPath)\$($DriverPack.id).exe"
        $Extract = $False
        if (Test-Path -Path $SaveAs) {
            $hash = Get-FileHash $SaveAs -Algorithm MD5
            if ($hash.Hash -notlike $DriverPack.MD5){
                Get-Softpaq -Number $DriverPack.id -SaveAs $SaveAs -Quiet -Overwrite yes @Verbose
                $Ansible.Changed = $true; Write-Output "Changed 5"
                $Extract = $True
            }
        } else {
            Get-Softpaq -Number $DriverPack.id -SaveAs $SaveAs -Quiet -Overwrite yes @Verbose
            $Ansible.Changed = $true; Write-Output "Changed 6"
            $Extract = $true
        }
        if ($Extract) {
            $DownloadDriverPackExtractFullPath = "$($ExtractedDir)\$($DriverPack.ID)\$($DriverPack.Version.split(" ") -join '')"
            $DownloadDriverPackExtractParentPath = "$($ExtractedDir)\$($DriverPack.ID)"
            if (!(Test-Path $DownloadDriverPackExtractFullPath)) {
                if (Test-Path $DownloadDriverPackExtractParentPath) {
                    Remove-Item -Path $DownloadDriverPackExtractParentPath -Recurse -Force -ErrorAction SilentlyContinue @Verbose | Out-Null
                    $Ansible.Changed = $true; Write-Output "Changed 7"
                }
                New-Item -Path $DownloadDriverPackExtractFullPath -ItemType Directory -Force @Verbose | Out-Null
                $Ansible.Changed = $true; Write-Output "Changed 8"
            }
            Start-Process $SaveAs -ArgumentList "-e -s -f $DownloadDriverPackExtractFullPath" -Wait @Verbose
        }
    } else {
        Write-Error "No Driver Pack found for $Model, Product Code: $ProdCode"
        #$Ansible.Failed = $true
    }
}

function Invoke-LenovoDriverDownload {
    param (
        [String]
        $DownloadDir="E:\DriverPacks\Lenovo-Repository",
        [String]
        $ExtractedDir,
        [String]
        $DeploymentShare="C:\Imaging\MDTUSB",
        [String[]]
        $ProdCode,
        [String[]]
        $Models
    )
    $content = (Invoke-WebRequest -Uri "https://download.lenovo.com/cdrt/td/catalogv2.xml").Content.Split("`n").Split("`r")
    $content[0] = "<$($content[0].split('<')[1])"
    [xml]$catalog = $content


    $list = $catalog.ModelList.Model | Foreach-Object {
        [PSCustomObject]@{
            Model = $_.Name
            Type = $_.Types.Type
            BIOS = $_.BIOS | Foreach-Object {
                [PSCustomObject]@{
                    Version = $_.Version
                    Image = $_.Image
                    Link = $_.InnerText
                    FileName = $_.InnerText.Split('/')[-1]
                }
            }
            Drivers = $_.SCCM | Foreach-Object {
                try {
                    $Date = [DateTime]::ParseExact($_.InnerText.Split('.')[-2].TrimEnd('_nodpr').Split('_')[-1], "yyyyMMdd", $Null)
                }
                catch {
                }
                if ($null -eq $Date) {
                    try {
                        $Date = [DateTime]::ParseExact($_.InnerText.Split('.')[-2].TrimEnd('_nodpr').Split('_')[-1], "yyyyMM", $Null)
                    }
                    catch {
                    }
                }
                if ($null -eq $Date) {
                    $Date = $_.InnerText.Split('.')[-2].TrimEnd('_nodpr').Split('_')[-1]
                }
                [PSCustomObject]@{
                    Date = $Date
                    Version = $_.Version
                    Link = $_.InnerText
                    FileName = $_.InnerText.Split('/')[-1]
                }
            }
        }
    }

    $LatestDriverPack = $list | Foreach-Object {
        $latestdate = $_.Drivers | Sort-Object Date -Descending | Select-Object -First 1 -ExpandProperty Date
        $latestDrivers = $_.Drivers | Where-Object Date -like $latestdate
        if ($latestDrivers.Version -contains '*') {
            $latestDrivers = $latestDrivers | Where-Object Version -eq '*'
        } else {
            $latestDrivers = $latestDrivers | Sort-Object Version -Descending | Select-Object -First 1
        }
        [PSCustomObject]@{
            Model = $_.Model
            Type = $_.Type
            DriverPack = $latestDrivers
        }
    }

    $DriverPack = $LatestDriverPack | Where-Object Model -like $Models | Select-Object -First 1 #Found duplicates in catalog with exact same properties according to Compare-Object

    if ($DriverPack) {

        $Date = [DateTime]::Today

        $DownloadDir = "$DownloadDir\$($DriverPack.DriverPack.FileName.Split('.')[0])"

        if (!(Test-Path $DownloadDir)) {
            New-Item $DownloadDir -ItemType Directory
            $Ansible.Changed = $true; Write-Output "Changed 9"
        }

        $filename = $DriverPack.DriverPack.FileName
        $Destination = "$DownloadDir\$filename"

        if (!(Test-Path $Destination)) {
            Invoke-WebRequest -Uri $DriverPack.DriverPack.Link -OutFile $Destination
            $Ansible.Changed = $true; Write-Output "Changed 10"
        }
        $Date | Export-Clixml "$DownloadDir\LastUseDate.xml"

        $ExtractedDir = "$DownloadDir\$($filename.split('.')[0])"
        $ExtractArgs = '/VERYSILENT /DIR="' + $ExtractedDir + '" /Extract="YES"'

        if (!(Test-Path $ExtractedDir)) {
            Start-Process $Destination $ExtractArgs
            $Ansible.Changed = $true; Write-Output "Changed 11"
        }
    } elseif ($DriverPack.count -gt 1) {
        Write-Error "Multiple Driver packs found for $Models"
        $Ansible.Failed = $true
    } else {
        Write-Error "No Driver packs found for $Models"
        $Ansible.Failed = $true
    }
}

function Invoke-DellDriverDownload {
    param(
        [String]
        $DeploymentShare,
        [String]
        $ExtractedDir="E:\DriverPacks\Dell\Extracted",
        [String]
        $DownloadDir="E:\DriverPacks\Dell",
        [String[]]
        $Models,
        [String]
        $WindowsVersion="Windows10"
    )

    $DellDownloadList = "http://downloads.dell.com/published/Pages/index.html"
    $DellDownloadBase = "http://downloads.dell.com"
    $DellDriverListURL = "http://en.community.dell.com/techcenter/enterprise-client/w/wiki/2065.dell-command-deploy-driver-packs-for-enterprise-client-os-deployment"
    $DellBaseURL = "http://en.community.dell.com"
    $Dell64BIOSUtil = "http://en.community.dell.com/techcenter/enterprise-client/w/wiki/12237.64-bit-bios-installation-utility"

    # Define Dell Download Sources
    $DellXMLCabinetSource = "http://downloads.dell.com/catalog/DriverPackCatalog.cab"
    $DellCatalogSource = "http://downloads.dell.com/catalog/CatalogPC.cab"

    # Define Dell Cabinet/XL Names and Paths
    $DellCabFile = [string]($DellXMLCabinetSource | Split-Path -Leaf)
    $DellCatalogFile = [string]($DellCatalogSource | Split-Path -Leaf)
    $DellXMLFile = $DellCabFile.Trim(".cab")
    $DellXMLFile = $DellXMLFile + ".xml"
    $DellCatalogXMLFile = $DellCatalogFile.Trim(".cab") + ".xml"

    # Define Dell Global Variables
    $DellCatalogXML = $null
    $DellModelXML = $null
    $DellModelCabFiles = $null

    # ArrayList to store models in
    $DellProducts = New-Object -TypeName System.Collections.ArrayList
    $DellKnownProducts = New-Object -TypeName System.Collections.ArrayList

    $DellProducts.Clear()

    if (!(Test-Path -Path $DownloadDir\$DellCabFile -NewerThan ([datetime]::Today).Add(-30))) {
        # Download Dell Model Cabinet File
        Invoke-WebRequest -Uri $DellXMLCabinetSource -OutFile "$DownloadDir\$DellCabFile" -TimeoutSec 120

        # Expand Cabinet File
        Expand.exe -F:* $DownloadDir\$DellCabFile $DownloadDir\$DellXMLFile
    }

    # Read XML File
    [xml]$DellModelXML = Get-Content -Path $DownloadDir\$DellXMLFile
    # Set XML Object
    $DellModelXML.GetType().FullName > $null
    $DellModelCabFiles = $DellModelXML.driverpackmanifest.driverpackage

    $ModelURL = $DellDownloadBase + "/" + ($DellModelCabFiles | Where-Object { ((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.Name -like "*$Model*") }).delta
    $ModelURL = $ModelURL.Replace("\", "/")
    $DriverDownload = $DellDownloadBase + "/" + ($DellModelCabFiles | Where-Object { ((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.Name -like "*$Model") }).path
    $DriverCab = (($DellModelCabFiles | Where-Object { ((($_.SupportedOperatingSystems).OperatingSystem).osCode -like "*$WindowsVersion*") -and ($_.SupportedSystems.Brand.Model.Name -like "*$Model") }).path).Split("/") | select -Last 1
    $DriverRevision = (($DriverCab).Split("-")[2]).Trim(".cab")

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
        Invoke-HPDriverDownload @invoke_args
    }
    "Dell" {
        #Invoke-DellDriverDownload @invoke_args
        Write-Warning "No Driver Automation for Dell implemented."
    }
    "Lenovo" {
        Invoke-LenovoDriverDownload @invoke_args
    }
    "Panasonic" {
        #Invoke-PanasonicDriverDownload @invoke_args
        Write-Warning "No Driver Automation for Panasonic implemented."
    }
    "Microsoft" {
        #Invoke-MicrosoftDriverDownload @invoke_args
        Write-Warning "No Driver Automation for Microsoft implemented."
    }
}