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

function Update-MDTDrivers {
    param(
        [String]$Root,
        [String]$ProdCode,
        [String]$Model,
        [String]$Type,
        [String]$Pack,
        [String]$DownloadDriverPackExtractFullPath,
        [String[]]$SupportedModels
    )
    switch ($Type) {
        "Model" {
            $Target = $Model
            if ($ProdCode) {
                $NewPath = "$Root\Models\$Model\$ProdCode\$Pack"
                $OldPath = "$Root\Models\$Model\$ProdCode"
            } else {
                $NewPath = "$Root\Models\$Model\$Pack"
                $OldPath = "$Root\Models\$Model"
            }
        }
        "Product" {
            $Target = $ProdCode
            $NewPath = "$Root\Products\$ProdCode\$Pack"
            $OldPath = "$Root\Products\$ProdCode"
        }
        "Version" {
            $Target = $Model
            $NewPath = "$Root\Versions\$Model\$Pack"
            $OldPath = "$Root\Versions\$Model"
        }
    }
    $output = @{
        Changed = $False
        Messages = @()
        Failed = $False
    }
    try {
        if (Test-Path $($NewPath)) {
            $output.Messages += "$Target Driverpack already Current"
        } else {
            #remove old driver paths in $deploymentshare
            if (Test-Path $OldPath) {
                Remove-Item -Path "$OldPath" -Recurse -ErrorAction SilentlyContinue @Verbose
                $output.Messages += "Removing out of date Drivers folder: $OldPath"
            }
            $output.Messages += "Creating new folder: $NewPath"
            switch ($Type) {
                "Model" {
                    if (!(Test-Path -Path $NewPath)) {
                        if (!(Test-Path "$Root\Models")) {
                            New-Item -Path $Root -enable "True" -Name "Models" -Comments "Models folder" -ItemType "folder" @Verbose
                        }
                        if (!(Test-Path "$Root\Models\$Model")) {
                            New-Item -Path "$Root\Models" -enable "True" -Name "$Model" -Comments "$Model" -ItemType "folder" @Verbose
                        }
                        if ($ProdCode) {
                            if (!(Test-Path "$Root\Models\$Model\$ProdCode")) {
                                if ($SupportedModels) {
                                    New-Item -Path "$Root\Models\$Model" -enable "True" -Name "$ProdCode" -Comments "$SupportedModels" -ItemType "folder" @Verbose
                                } else {
                                    New-Item -Path "$Root\Models\$Model" -enable "True" -Name "$ProdCode" -ItemType "folder" @Verbose
                                }
                            }
                        } else {
                            if (!(Test-Path "$Root\Models\$Model\$ProdCode")) {
                                if ($SupportedModels) {
                                    New-Item -Path "$Root\Models\$Model" -enable "True" -Name "$ProdCode" -Comments "$SupportedModels" -ItemType "folder" @Verbose
                                } else {
                                    New-Item -Path "$Root\Models\$Model" -enable "True" -Name "$ProdCode" -ItemType "folder" @Verbose
                                }
                            }
                        }
                        if (!(Test-Path "$Root\Models\$Model\$ProdCode\$Pack")) {
                            New-Item -Path "$Root\Models\$Model\$ProdCode" -Name $Pack -Comments "Version of Driver Pack - $((Get-Date).ToShortDateString())" -ItemType "folder" @Verbose
                        }
                    }
                }
                "ProdCode" {
                    if (!(Test-Path -Path $NewPath)) {
                        if (!(Test-Path "$Root\Products")) {
                            New-Item -Path "$Root" -enable "True" -Name "Products" -Comments "Product Code folder" -ItemType "folder" @Verbose
                        }
                        if (!(Test-Path "$Root\Products\$ProdCode")) {
                            New-Item -Path "$Root\Products" -enable "True" -Name "$ProdCode" -Comments "$SupportedModels" -ItemType "folder" @Verbose
                        }
                        if (!(Test-Path "$Root\Products\$ProdCode\$Pack")) {
                            New-Item -Path "$Root\Products\$ProdCode" -Name $Pack -Comments "Version of Driver Pack - $((Get-Date).ToShortDateString())" -ItemType "folder" @Verbose
                        }
                    }
                }
                "Version" {
                    if (!(Test-Path -Path $NewPath)) {
                        if (!(Test-Path "$Root\Versions")) {
                            New-Item -Path "$Root" -enable "True" -Name "Versions" -Comments "Lenovo Version-Model folder" -ItemType "folder" @Verbose
                        }
                        if (!(Test-Path "$Root\Versions\$Model")) {
                            New-Item -Path "$Root\Versions" -enable "True" -Name "$Model" -ItemType "folder" @Verbose
                        }
                        if (!(Test-Path "$Root\Versions\$Model\$Pack")) {
                            New-Item -Path "$Root\Versions\$Model" -Name $Pack -Comments "Version of Driver Pack - $((Get-Date).ToShortDateString())" -ItemType "folder" @Verbose
                        }
                    }
                }
            }

            #import updated drivers into deployment share
            $output.Messages += "Importing $($DownloadDriverPackExtractFullPath) into MDT $($NewPath)"
            Import-MDTDriver -Path $NewPath -SourcePath "$DownloadDriverPackExtractFullPath" | Out-Null
            $output.Changed = $true
        }
    }
    catch {
        $output.Failed = $True
    }
    return $output
}

function Invoke-HPDriverImport {
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

    $MDTModule = "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

    Import-Module $MDTModule

    if (!(Get-PSDrive -LiteralName DS001 -ErrorAction 'silentlycontinue')) {
        New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $deploymentshare @Verbose | Out-Null
    } else {
        Remove-PSDrive DS001 | Out-Null
        New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $deploymentshare @Verbose | Out-Null
    }

    Set-Location "$DownloadDir"
    $info = Get-RepositoryInfo | Select-Object -ExpandProperty Filters | Where-Object {$_.platform -like $ProdCode}
    if ($info) {
        $SoftPaqParams = @{
            Category = 'DriverPack'
            Platform = $ProdCode
            Os = $info.operatingSystem.split(':')[0]
            OsVer = $info.operatingSystem.split(':')[1]
        }
        $SoftPaq = Get-SoftpaqList @SoftPaqParams -Quiet -ErrorAction SilentlyContinue @Verbose
    }

    $DriverPack = $SoftPaq | Where-Object { $_.category -eq 'Manageability - Driver Pack' }
    $DriverPack = $DriverPack | Where-Object { $_.Name -notlike "*Windows*PE*" }
    $DriverPack = $DriverPack | Where-Object { $_.Name -notlike "*WinPE*" }

    if ($DriverPack) {
        $MetaData = Invoke-WebRequest -Uri "https://$($DriverPack.MetaData)" | Select-Object -ExpandProperty Content
        $IniData = $MetaData | ConvertFrom-Ini
        $keys = $IniData.'System Information'.Keys.split()
        $count = ($keys.count / 2)
        $SystemInformation = 1..$count | Foreach-Object {
             if ($_.length -eq 1) {
                  $index = "0$_"
             } else {
                  $index = $_.ToString()
             }
             $System = $keys | Where-Object {$_ -like "*$Index"}
             [PSCustomObject]@{
                  ProductCode = $IniData.'System Information'[$System[0]].split('x')[1]
                  Models = $IniData.'System Information'[$System[1]].Split(',')
             }
        }
        $DownloadDriverPackExtractFullPath = "$($ExtractedDir)\$($DriverPack.ID)\$($DriverPack.Version.split(" ") -join '')"

        $Root = 'DS001:\Out-of-Box Drivers\Win10'
        $DriverPackVersion = ($DriverPack.Version.split(" ") -join '')
        $UpdateMDTParameters = @{
            Root = $Root
            Pack = $DriverPackVersion
            DownloadDriverPackExtractFullPath = $DownloadDriverPackExtractFullPath
        }
        $SupportedModels = $SystemInformation | Where-Object ProdCode -like $ProdCode | Select-Object -ExpandProperties Models
        $Result = Update-MDTDrivers @UpdateMDTParameters -ProdCode $ProdCode -Type "Product" -SupportedModels $SupportedModels
        if ($Result.Changed) {
            $Ansible.Changed = $True; Write-Output "Changed 1"
        }
        if ($Result.Failed) {
            $Ansible.Failed = $True
        }
        $Result.Messages | Write-Output
        foreach ($Model in $Models) {
            $Result = Update-MDTDrivers @UpdateMDTParameters -ProdCode $ProdCode -Type "Model" -Model $Model -SupportedModels $SupportedModels
            if ($Result.Changed) {
                $Ansible.Changed = $True; Write-Output "Changed 2"
            }
            if ($Result.Failed) {
                $Ansible.Failed = $True
            }
            $Result.Messages | Write-Output
        }
        foreach ($System in $SystemInformation) {
            $Result = Update-MDTDrivers @UpdateMDTParameters -ProdCode $System.ProdCode -Type "Product" -SupportedModels $System.Models
            if ($Result.Changed) {
                $Ansible.Changed = $True; Write-Output "Changed 3"
            }
            if ($Result.Failed) {
                $Ansible.Failed = $True
            }
            $Result.Messages | Write-Output
        }
    } else {
        Write-Error "No Driver Pack found for $Model, Product Code: $ProdCode"
        #$Ansible.Failed = $true
    }
}

function  Invoke-LenovoDriverImport {
    param (
        [String]
        $DownloadDir="E:\DriverPacks\Lenovo-Repository",
        [String]
        $ExtractedDir,
        [String]
        $DeploymentShare="C:\Imaging\MDTUSB",
        [String]
        $ProdCode,
        [String[]]
        $Models
    )
    $MDTModule = "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

    Import-Module $MDTModule

    if (!(Get-PSDrive -LiteralName DS001 -ErrorAction 'silentlycontinue')) {
        New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $deploymentshare @Verbose | Out-Null
    } else {
        Remove-PSDrive DS001 | Out-Null
        New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $deploymentshare @Verbose | Out-Null
    }
    #$uri = "https://download.lenovo.com/cdrt/td/catalog.xml"
    $uri = "https://download.lenovo.com/cdrt/td/catalogv2.xml"

    $content = (Invoke-WebRequest -Uri $uri).Content.Split("`n").Split("`r")
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

        $RootDir = $DownloadDir
        $DownloadDir = "$RootDir\$($DriverPack.DriverPack.FileName.Split('.')[0])"

        $filename = $DriverPack.DriverPack.FileName

        $Date | Export-Clixml "$DownloadDir\LastUseDate.xml"

        $ExtractedDir = "$DownloadDir\$($filename.split('.')[0])"
        $Root = 'DS001:\Out-of-Box Drivers\Win10'
        $DriverPackVersion = $DriverPack.DriverPack.Date.ToString("yyyyMMdd")
        $UpdateMDTParameters = @{
            Root = $Root
            Pack = $DriverPackVersion
            DownloadDriverPackExtractFullPath = $ExtractedDir
        }
        $Result = Update-MDTDrivers @UpdateMDTParameters -ProdCode $ProdCode -Type "Version" -Model $Models
        if ($Result.Changed) {
            $Ansible.Changed = $True; Write-Output "Changed 4"
        }
        if ($Result.Failed) {
            $Ansible.Failed = $True
        }
        $Result.Messages | Write-Output
    } elseif ($DriverPack.count -gt 1) {
        Write-Error "Multiple Driver packs found for $($ProdCode): $Model"
    } else {
        Write-Error "No Driver packs found for $($ProdCode): $Model"
    }

}

$Verbose = @{
    Verbose = $false
}

$Ansible.Changed = $false

$MDTModule = "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"

Import-Module $MDTModule

if (!(Get-PSDrive -LiteralName DS001 -ErrorAction 'silentlycontinue')) {
    New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $deploymentshare @Verbose | Out-Null
} else {
    Remove-PSDrive DS001 | Out-Null
    New-PSDrive -Name "DS001" -PSProvider MDTProvider -Root $deploymentshare @Verbose | Out-Null
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
        Invoke-HPDriverImport @invoke_args
    }
    "Lenovo" {
        Invoke-LenovoDriverImport @invoke_args
    }
    "Dell" {
        #Invoke-DellDriverImport @invoke_args
        Write-Warning "No Driver Automation for Dell implemented."

    }
    "Panasonic" {
        #Invoke-PanasonicDriverImport @invoke_args
        Write-Warning "No Driver Automation for Panasonic implemented."

    }
    "Microsoft" {
        #Invoke-MicrosoftDriverImport @invoke_args
        Write-Warning "No Driver Automation for Microsoft implemented."

    }
}
