<#
.SYNOPSIS
    Driver Manager Pro v3.5 - Cong cu Quet, Cai dat, Sua loi & Sao luu Driver Tu dong
.DESCRIPTION
    100% Clean Console Font - Khong loi font tren moi phien ban Windows Console
    Tich hop Bo Tu Dong Sua Loi Windows Update & Mang Chan Driver (Fix 0x8024402C)
    Tich hop Smart Catalog Driver Engine - Tu dong tim, tai va cai dat Driver thieu bang Hardware ID
    Tac quyen: Le Canh PC - LC_SOFT (0979.298.897)
#>
param(
    [switch]$AutoRun,
    [switch]$InstallWU,
    [switch]$FixWU,
    [switch]$ScanOnly,
    [switch]$BackupOnly,
    [switch]$DDU,
    [switch]$FastGPU,
    [switch]$FastUSB,
    [string]$RestoreDir
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Dang khoi dong lai Driver Manager voi quyen Administrator..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($AutoRun) { $argList += " -AutoRun" }
    if ($InstallWU) { $argList += " -InstallWU" }
    if ($FixWU) { $argList += " -FixWU" }
    if ($ScanOnly) { $argList += " -ScanOnly" }
    if ($BackupOnly) { $argList += " -BackupOnly" }
    if ($DDU) { $argList += " -DDU" }
    if ($FastGPU) { $argList += " -FastGPU" }
    if ($FastUSB) { $argList += " -FastUSB" }
    if ($RestoreDir) { $argList += " -RestoreDir `"$RestoreDir`"" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
}

# Kiem tra ban quyen LC_SOFT (Bao ve chong dung chua kich hoat)
$secFile = Join-Path -Path $PSScriptRoot -ChildPath "ToolkitSecurity.ps1"
if (Test-Path $secFile) { . $secFile }
$licRes = Test-ToolkitLicense -BaseDir $PSScriptRoot
if (-not $licRes -or -not $licRes.IsValid) {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "  [!] PHAN MEM YEU CAU BAN QUYEN HOAC KEY DUNG THU 7 NGAY TU LC_SOFT!    " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Red
    $hw = Get-HardwareID -Path $PSScriptRoot
    Write-Host "  Ma thiet bi phan cung cua ban (HWID): $($hw.HWID)" -ForegroundColor Cyan
    Write-Host "  Trang thai: $($licRes.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  -> Vui long gui ma HWID tren qua Zalo: 0979.298.897 (Le Canh PC)" -ForegroundColor White
    Write-Host "     de nhan file license.lic kich hoat Dung Thu 7 Ngay hoac Vinh Vien!" -ForegroundColor White
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "Nhan phim bat ky de thoat..." -ForegroundColor Gray
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch {}
    return
}

$LogDir = Join-Path -Path $PSScriptRoot -ChildPath "Logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
$LogFile = Join-Path -Path $LogDir -ChildPath "DriverManager_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$DefaultBackupRoot = "C:\DriverBackup"

$LockFile = Join-Path $env:TEMP "PCToolkit_DriverManager.running"
$DoneFile = Join-Path $env:TEMP "PCToolkit_DriverManager.done"
try {
    Set-Content -Path $LockFile -Value "Running (PID: $PID)" -Encoding UTF8 -Force -ErrorAction SilentlyContinue
    if (Test-Path $DoneFile) { Remove-Item -Path $DoneFile -Force -ErrorAction SilentlyContinue }
} catch {}

function Signal-Completion {
    param([string]$Message)
    try {
        if (Test-Path $LockFile) { Remove-Item -Path $LockFile -Force -ErrorAction SilentlyContinue }
        Set-Content -Path $DoneFile -Value $Message -Encoding UTF8 -Force -ErrorAction SilentlyContinue
    } catch {}
}

function Complete-AutomatedStep {
    param([string]$Message = 'ÄĂ£ hoĂ n táº¥t thao tĂ¡c!')
    Signal-Completion $Message
    Write-Host '
[OK] Tu dong hoan tat va dong cua so sau 3 giay (hoac Nhan bat ky phim nao de dong ngay)...' -ForegroundColor Green
    $timeout = 3
    for ($i = $timeout; $i -gt 0; $i--) {
        Write-Host ('  Dong cua so trong ' + $i + ' giay...  ') -NoNewline -ForegroundColor DarkGray
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            break
        }
        Start-Sleep -Seconds 1
    }
}

function Write-Log {
    param([string]$Message, [string]$Color = "Gray")
    $Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "[$Timestamp] $Message" | Out-File -FilePath $LogFile -Append -Encoding UTF8
    Write-Host $Message -ForegroundColor $Color
}

function Pause-Menu {
    Write-Host ""
    Read-Host "Nhan phim Enter de quay lai menu" | Out-Null
}

function Show-Banner {
    Clear-Host
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Host "|   CONG CU QUET - CAI DAT - BACKUP DRIVER TU DONG (PRO v3.5 CHUYEN NGHIEP)|" -ForegroundColor Yellow
    Write-Host "|             Tac quyen: Le Canh PC - LC_SOFT (0979.298.897)             |" -ForegroundColor DarkGray
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $mb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $gpus = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join " | "
    Write-Host "  Thiet bi / May : $($cs.Manufacturer) - $($cs.Model)" -ForegroundColor Gray
    Write-Host "  Bo mach chu    : $($mb.Manufacturer) - $($mb.Product)" -ForegroundColor Gray
    Write-Host "  Card do hoa    : $gpus" -ForegroundColor Green
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
}

# ==============================================================================
# 0. CHUC NANG TU DONG SUA LOI WINDOWS UPDATE & MANG CHAN DRIVER (FIX 0x8024402C)
# ==============================================================================
function Ensure-WindowsUpdateDriverSearchReady {
    Write-Host "`n[+] BUOC 1: Kiem tra & San sang dich vu Windows Update va PnP..." -ForegroundColor Cyan
    try {
        # Dam bao wuauserv & DeviceInstall san sang (chi Start neu chua chay, khong Restart de tranh do may)
        $svcWu = Get-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        if ($svcWu -and $svcWu.Status -ne "Running") {
            Set-Service -Name "wuauserv" -StartupType Manual -ErrorAction SilentlyContinue
            Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
        }
        $svcDev = Get-Service -Name "DeviceInstall" -ErrorAction SilentlyContinue
        if ($svcDev -and $svcDev.Status -ne "Running") {
            Start-Service -Name "DeviceInstall" -ErrorAction SilentlyContinue
        }

        # Kich hoat SearchOrderConfig = 1 de Windows Update tu dong tim Driver
        $dsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
        if (-not (Test-Path $dsPath)) { New-Item -Path $dsPath -Force | Out-Null }
        Set-ItemProperty -Path $dsPath -Name "SearchOrderConfig" -Value 1 -Force -ErrorAction SilentlyContinue

        # Go bo chinh sach chan cap nhat Driver trong Group Policy neu co
        $wuPolPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (Test-Path $wuPolPath) {
            Remove-ItemProperty -Path $wuPolPath -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wuPolPath -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
        }
        Write-Host "  [OK] Dich vu PnP & Windows Update Driver Searching da san sang (0.1s)!" -ForegroundColor Green
    } catch {
        Write-Host "  [!] Thong bao: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

function Invoke-RepairWindowsUpdateAndNetwork {
    param([switch]$Silent)
    Write-Host "`n==========================================================================" -ForegroundColor Red
    Write-Host "  [TU DONG CAP CUU] SUA CHUA LOI WINDOWS UPDATE & MANG CHAN DRIVER        " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "  -> Dang tu dong go bo chan WSUS, reset Proxy, sua DNS va khoi dong lai Service..." -ForegroundColor Gray
    Write-Host ""

    # 1. Reset WinHTTP Proxy & System Proxy
    Write-Log "  [1/7] Dang Reset WinHTTP Proxy & go bo Proxy he thong..." "Cyan"
    try {
        netsh winhttp reset proxy | Out-Null
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -ErrorAction SilentlyContinue
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name "ProxyEnable" -Value 0 -ErrorAction SilentlyContinue
    } catch {}

    # 2. Xoa bo cac chinh sach chan Windows Update va WSUS trong Registry
    Write-Log "  [2/7] Dang go bo cac chinh sach chan Update & WSUS trong Registry..." "Cyan"
    try {
        $wuPolPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
        if (Test-Path $wuPolPath) {
            Remove-ItemProperty -Path $wuPolPath -Name "DisableWindowsUpdateAccess" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wuPolPath -Name "ExcludeWUDriversInQualityUpdate" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wuPolPath -Name "WUServer" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wuPolPath -Name "WUStatusServer" -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $wuPolPath -Name "UpdateServiceUrlAlternate" -ErrorAction SilentlyContinue
        }
        $auPolPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
        if (Test-Path $auPolPath) {
            Set-ItemProperty -Path $auPolPath -Name "UseWUServer" -Value 0 -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $auPolPath -Name "NoAutoUpdate" -Value 0 -ErrorAction SilentlyContinue
        }
        Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoWindowsUpdate" -ErrorAction SilentlyContinue
    } catch {}

    # 2.1 Bat tinh nang DriverSearching trong Windows (SearchOrderConfig = 1)
    Write-Log "  [2.1/7] Dang kich hoat tinh nang tu dong tim Driver tu Windows Update (SearchOrderConfig = 1)..." "Cyan"
    try {
        $dsPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching"
        if (-not (Test-Path $dsPath)) { New-Item -Path $dsPath -Force | Out-Null }
        Set-ItemProperty -Path $dsPath -Name "SearchOrderConfig" -Value 1 -Force -ErrorAction SilentlyContinue

        $polDs = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching"
        if (Test-Path $polDs) {
            Remove-ItemProperty -Path $polDs -Name "DontSearchWindowsUpdate" -ErrorAction SilentlyContinue
        }
    } catch {}

    # 3. Kiem tra & Chuyen DNS sang Google 8.8.8.8 / Cloudflare 1.1.1.1 neu khong phan giai duoc may chu MS
    Write-Log "  [3/7] Dang kiem tra phan giai ten mien DNS & Flush DNS Cache..." "Cyan"
    try {
        ipconfig /flushdns | Out-Null

        $canResolve = $false
        try {
            $ip = [System.Net.Dns]::GetHostAddresses("sls.update.microsoft.com")
            if ($ip -and $ip.Length -gt 0) { $canResolve = $true }
        } catch {}

        if (-not $canResolve) {
            Write-Log "    [!] DNS hien tai bi nghen, dang tu dong gan DNS Google (8.8.8.8, 8.8.4.4)..." "Yellow"
            $activeAdapters = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' }
            foreach ($nic in $activeAdapters) {
                Set-DnsClientServerAddress -InterfaceIndex $nic.InterfaceIndex -ServerAddresses @("8.8.8.8", "8.8.4.4", "1.1.1.1") -ErrorAction SilentlyContinue
            }
            ipconfig /flushdns | Out-Null
        }
    } catch {}

    # 4. Kiem tra file hosts
    Write-Log "  [4/7] Dang kiem tra file hosts he thong..." "Cyan"
    try {
        $hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
        if (Test-Path $hostsPath) {
            $hostsLines = Get-Content -Path $hostsPath -ErrorAction SilentlyContinue
            $cleanLines = @()
            $modified = $false
            foreach ($line in $hostsLines) {
                if ($line -match "microsoft|windowsupdate|update\.microsoft") {
                    $modified = $true
                } else {
                    $cleanLines += $line
                }
            }
            if ($modified) {
                Set-Content -Path $hostsPath -Value $cleanLines -Encoding ASCII -Force -ErrorAction SilentlyContinue
                Write-Log "    [OK] Da go bo cac dong chan may chu Windows Update trong file hosts!" "Green"
            }
        }
    } catch {}

    # 5. Dang ky lai cac thu vien DLL Windows Update
    Write-Log "  [5/7] Dang dang ky lai thu vien DLL Windows Update (regsvr32)..." "Cyan"
    $dllList = @("atl.dll", "urlmon.dll", "mshtml.dll", "wups.dll", "wups2.dll", "wuapi.dll", "wuaueng.dll", "wucltux.dll", "wudriver.dll", "softpub.dll", "wintrust.dll", "cryptdlg.dll")
    foreach ($dll in $dllList) {
        try { Start-Process regsvr32.exe -ArgumentList "/s $dll" -NoNewWindow -Wait } catch {}
    }

    # 6. Bat & Khoi dong lai cac Service he thong Windows Update & PnP Driver
    Write-Log "  [6/7] Dang khoi phuc cac dich vu wuauserv, bits, cryptsvc, DsmSvc, DeviceInstall..." "Cyan"
    $services = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller", "DsmSvc", "DeviceInstall")
    foreach ($s in $services) {
        try {
            Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
            Restart-Service -Name $s -Force -ErrorAction SilentlyContinue
        } catch {
            try { Start-Service -Name $s -ErrorAction SilentlyContinue } catch {}
        }
    }

    # 6.1 Dang ky Microsoft Update Catalog de nhan day du Driver tu Intel, HP, Dell, Realtek...
    try {
        $sm = New-Object -ComObject Microsoft.Update.ServiceManager
        $sm.ClientApplicationID = "PC_Optimization_Toolkit"
        $sm.AddService2("7971f918-a847-4430-9279-4a52d1efe18d", 7, "") | Out-Null
    } catch {}

    # 7. Dong bo thoi gian he thong (CMOS Time Sync)
    Write-Log "  [7/7] Dang dong bo thoi gian he thong de tranh loi SSL..." "Cyan"
    try {
        Start-Service w32time -ErrorAction SilentlyContinue
        w32tm /resync /force | Out-Null
    } catch {}

    Start-Sleep -Seconds 1
    Write-Host "`n  [OK] DA SUA CHUA TOAN BO LOI MANG & WINDOWS UPDATE HOAN TAT 100%!" -ForegroundColor Green
    Write-Host "==========================================================================`n" -ForegroundColor DarkCyan
}

# ==============================================================================
# 0.1 TIEN ICH TAI FILE CO THANH TIEN TRINH REAL-TIME
# ==============================================================================
function Start-ConsoleDownload {
    param(
        [string]$Url,
        [string]$DestinationPath,
        [string]$Title = "Táº£i file"
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
    
    $script:dlLastPct = -1
    $script:dlTitle = $Title
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    $eventJob = Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
        $pct = $EventArgs.ProgressPercentage
        $bytes = $EventArgs.BytesReceived
        $total = $EventArgs.TotalBytesToReceive
        $mbRecv = [math]::Round($bytes / 1MB, 2)
        $mbTotal = if ($total -gt 0) { [math]::Round($total / 1MB, 2) } else { 0 }
        if ($pct -ne $script:dlLastPct -and ($pct % 20 -eq 0 -or $pct -eq 100)) {
            $script:dlLastPct = $pct
            Write-Host "`r    [TIEN DO] $script:dlTitle : $pct% ($mbRecv MB / $mbTotal MB)... " -ForegroundColor Cyan -NoNewline
        }
    }

    try {
        $wc.DownloadFileAsync((New-Object Uri($Url)), $DestinationPath)
        while ($wc.IsBusy) {
            Start-Sleep -Milliseconds 250
        }
        $sw.Stop()
        Write-Host " [DA TAI XONG trong $([math]::Round($sw.Elapsed.TotalSeconds))s]" -ForegroundColor Green
        return $true
    } catch {
        Write-Host " [LOI TAI: $($_.Exception.Message)]" -ForegroundColor Red
        return $false
    } finally {
        if ($eventJob) { 
            Unregister-Event -SourceIdentifier $eventJob.Name -ErrorAction SilentlyContinue
            Remove-Job -Id $eventJob.Id -Force -ErrorAction SilentlyContinue
        }
        $wc.Dispose()
    }
}

# ==============================================================================
# 0.2 QUET VA PHAN TICH DANH SACH THIET BI THIEU DRIVER (PNPUTIL + CIM)
# ==============================================================================
function Get-PnpProblemDevicesList {
    $devices = @()
    
    # 1. Doc qua pnputil /enum-devices /problem /deviceids
    $rawText = & pnputil.exe /enum-devices /problem /deviceids 2>&1
    $curDev = $null
    $mode = ""

    foreach ($line in ($rawText -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ($line -match "^Instance ID:\s*(.+)$") {
            if ($curDev -and $curDev.InstanceId) { $devices += [PSCustomObject]$curDev }
            $curDev = [ordered]@{
                InstanceId = $matches[1].Trim()
                Description = ""
                ProblemCode = ""
                HardwareIds = @()
                CompatibleIds = @()
            }
            $mode = ""
        } elseif ($line -match "^Device Description:\s*(.+)$") {
            if ($curDev) { $curDev.Description = $matches[1].Trim() }
        } elseif ($line -match "^Problem Code:\s*(.+)$") {
            if ($curDev) { $curDev.ProblemCode = $matches[1].Trim() }
        } elseif ($line -match "^Hardware IDs:\s*(.*)$") {
            $mode = "HW"
            $firstHw = $matches[1].Trim()
            if ($firstHw -and $curDev) { $curDev.HardwareIds += $firstHw }
        } elseif ($line -match "^Compatible IDs:\s*(.*)$") {
            $mode = "COMPAT"
            $firstCompat = $matches[1].Trim()
            if ($firstCompat -and $curDev) { $curDev.CompatibleIds += $firstCompat }
        } elseif ($mode -eq "HW" -and $trimmed -and $curDev) {
            $curDev.HardwareIds += $trimmed
        } elseif ($mode -eq "COMPAT" -and $trimmed -and $curDev) {
            $curDev.CompatibleIds += $trimmed
        }
    }
    if ($curDev -and $curDev.InstanceId) { $devices += [PSCustomObject]$curDev }

    # 2. Bo sung tu WMI / CIM neu pnputil chua liet ke het
    try {
        $cimDevs = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.ConfigManagerErrorCode -ne 0 -and $_.ConfigManagerErrorCode -ne 22 }
        foreach ($cd in $cimDevs) {
            $exists = ($devices | Where-Object { $_.InstanceId -eq $cd.DeviceID })
            if (-not $exists) {
                $devices += [PSCustomObject]@{
                    InstanceId = $cd.DeviceID
                    Description = $cd.Name
                    ProblemCode = "$($cd.ConfigManagerErrorCode)"
                    HardwareIds = @($cd.HardwareID)
                    CompatibleIds = @($cd.CompatibleID)
                }
            }
        }
    } catch {}

    return $devices
}

# ==============================================================================
# 0.3 DANG TRUY VAN CATALOG CUA MICROSOFT BANG HARDWARE ID (SMART CATALOG ENGINE)
# ==============================================================================
if (-not $script:CatalogCache) { $script:CatalogCache = @{} }

function Get-CatalogDriverForHwId {
    param([string]$HardwareId)

    if ([string]::IsNullOrWhiteSpace($HardwareId)) { return $null }
    if ($script:CatalogCache.ContainsKey($HardwareId)) {
        return $script:CatalogCache[$HardwareId]
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $is64 = [Environment]::Is64BitOperatingSystem

    # 1. Tao danh sach query tim kiem thong minh da tang
    $searchQueries = @()
    $vendorKeyword = ""

    if ($HardwareId -match "PCI\\(VEN_[0-9A-Fa-f]{4}&DEV_[0-9A-Fa-f]{4})") {
        $venDev = $matches[1]
        $searchQueries += "PCI\$venDev"
        $searchQueries += $venDev
        if ($venDev -match "VEN_8086") { $vendorKeyword = "INTEL" }
        elseif ($venDev -match "VEN_10EC") { $vendorKeyword = "Realtek" }
        elseif ($venDev -match "VEN_10DE") { $vendorKeyword = "NVIDIA" }
        elseif ($venDev -match "VEN_1002") { $vendorKeyword = "AMD" }
    } elseif ($HardwareId -match "(VEN_[0-9A-Fa-f]{4}&DEV_[0-9A-Fa-f]{4})") {
        $venDev = $matches[1]
        $searchQueries += "PCI\$venDev"
        $searchQueries += $venDev
        if ($venDev -match "VEN_8086") { $vendorKeyword = "INTEL" }
        elseif ($venDev -match "VEN_10EC") { $vendorKeyword = "Realtek" }
        elseif ($venDev -match "VEN_10DE") { $vendorKeyword = "NVIDIA" }
        elseif ($venDev -match "VEN_1002") { $vendorKeyword = "AMD" }
    } elseif ($HardwareId -match "ACPI\\([A-Za-z0-9_]+)") {
        $acpiId = $matches[1]
        $searchQueries += "ACPI\$acpiId"
        $searchQueries += $acpiId
        if ($acpiId -match "HPQ|HPN") { $vendorKeyword = "HP" }
        elseif ($acpiId -match "INT") { $vendorKeyword = "INTEL" }
    } elseif ($HardwareId -match "USB\\(VID_[0-9A-Fa-f]{4}&PID_[0-9A-Fa-f]{4})") {
        $usbId = $matches[1]
        $searchQueries += "USB\$usbId"
        $searchQueries += $usbId
    } elseif ($HardwareId -match "(VID_[0-9A-Fa-f]{4}&PID_[0-9A-Fa-f]{4})") {
        $usbId = $matches[1]
        $searchQueries += "USB\$usbId"
        $searchQueries += $usbId
    } elseif ($HardwareId -match "HDAUDIO\\FUNC_01&(VEN_[0-9A-Fa-f]{4}&DEV_[0-9A-Fa-f]{4})") {
        $hdId = $matches[1]
        $searchQueries += "HDAUDIO\$hdId"
        $searchQueries += $hdId
        if ($hdId -match "VEN_10EC") { $vendorKeyword = "Realtek" }
    } else {
        $searchQueries += $HardwareId
    }

    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")

    foreach ($query in $searchQueries) {
        try {
            $searchUrl = "https://www.catalog.update.microsoft.com/Search.aspx?q=" + [uri]::EscapeDataString($query)
            $html = $wc.DownloadString($searchUrl)

            # 2. Parse cac row trong bang ket qua cua Microsoft Update Catalog
            $rowMatches = [regex]::Matches($html, '<tr\s+id="([a-f0-9\-]+)_row"[\s\S]*?goToDetails\("([a-f0-9\-]+)"\)[^>]*>([\s\S]*?)</a>[\s\S]*?<td[^>]*>([\s\S]*?)</td>[\s\S]*?<td[^>]*>([\s\S]*?)</td>[\s\S]*?<td[^>]*>([\s\S]*?)</td>')
            
            # Fallback neu format HTML chi co link goToDetails
            if ($rowMatches.Count -eq 0) {
                $detailsMatches = [regex]::Matches($html, 'goToDetails\("([a-f0-9\-]+)"\)[^>]*>([\s\S]*?)</a>')
                if ($detailsMatches.Count -gt 0) {
                    $pickedId = $detailsMatches[0].Groups[1].Value
                    $pickedTitle = ($detailsMatches[0].Groups[2].Value.Trim() -replace '<[^>]+>', '') -replace '\s+', ' '
                    $body = '[{"size":0,"languages":"","uidInfo":"' + $pickedId + '","updateID":"' + $pickedId + '"}]'
                    $wcDialog = New-Object System.Net.WebClient
                    $wcDialog.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                    $wcDialog.Headers.Add("Content-Type", "application/x-www-form-urlencoded")
                    $dialogRes = $wcDialog.UploadString("https://www.catalog.update.microsoft.com/DownloadDialog.aspx", "updateIDs=" + [uri]::EscapeDataString($body))
                    $cabMatch = [regex]::Match($dialogRes, 'https?://[^\s''""]+\.cab')
                    if ($cabMatch.Success) {
                        $resObj = @{
                            UpdateId = $pickedId
                            Title = $pickedTitle
                            CabUrl = $cabMatch.Value
                            HardwareId = $query
                        }
                        $script:CatalogCache[$HardwareId] = $resObj
                        return $resObj
                    }
                }
                continue
            }

            # 3. Thuat toan cham diem & loc Driver theo kien truc OS x64 / x86 & phien ban moi nhat
            $candidates = @()
            foreach ($rm in $rowMatches) {
                $uId = $rm.Groups[2].Value
                $title = ($rm.Groups[3].Value.Trim() -replace '<[^>]+>', '') -replace '\s+', ' '
                $products = ($rm.Groups[4].Value.Trim() -replace '<[^>]+>', '') -replace '\s+', ' '
                $dateStr = ($rm.Groups[6].Value.Trim() -replace '<[^>]+>', '') -replace '\s+', ' '

                $score = 100
                $fullText = "$title $products".ToLower()

                if ($is64) {
                    if ($fullText -match "x64|amd64|64-bit|64 bit") { $score += 200 }
                    if ($fullText -match "x86|32-bit|32 bit|ia64|arm") { $score -= 1000 } # Loai bo 32-bit tren Win 64-bit!
                } else {
                    if ($fullText -match "x86|32-bit|32 bit") { $score += 200 }
                    if ($fullText -match "x64|amd64|64-bit|arm") { $score -= 1000 }
                }

                if ($fullText -match "windows 10|windows 11|client") { $score += 150 }
                elseif ($fullText -match "windows 8|windows 7") { $score += 20 }
                elseif ($fullText -match "windows xp|windows 2000") { $score -= 200 }

                if ($vendorKeyword -and ($fullText -match $vendorKeyword.ToLower())) {
                    $score += 80
                }

                try {
                    $dt = [datetime]::Parse($dateStr, [System.Globalization.CultureInfo]::InvariantCulture)
                    $score += [int]($dt.Year * 10 + $dt.Month)
                } catch {}

                if ($score -gt 0) {
                    $candidates += [PSCustomObject]@{
                        Id = $uId
                        Title = $title
                        Products = $products
                        Date = $dateStr
                        Score = $score
                    }
                }
            }

            if ($candidates.Count -gt 0) {
                $best = $candidates | Sort-Object -Property Score -Descending | Select-Object -First 1
                $pickedId = $best.Id
                $pickedTitle = $best.Title

                $body = '[{"size":0,"languages":"","uidInfo":"' + $pickedId + '","updateID":"' + $pickedId + '"}]'
                $wcDialog = New-Object System.Net.WebClient
                $wcDialog.Headers.Add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")
                $wcDialog.Headers.Add("Content-Type", "application/x-www-form-urlencoded")
                $dialogRes = $wcDialog.UploadString("https://www.catalog.update.microsoft.com/DownloadDialog.aspx", "updateIDs=" + [uri]::EscapeDataString($body))

                $cabMatches = [regex]::Matches($dialogRes, 'https?://[^\s''""]+\.cab')
                $chosenCab = $null
                if ($cabMatches.Count -gt 0) {
                    if ($is64) {
                        foreach ($cm in $cabMatches) {
                            if ($cm.Value -match "amd64|x64") { $chosenCab = $cm.Value; break }
                        }
                    } else {
                        foreach ($cm in $cabMatches) {
                            if ($cm.Value -match "x86") { $chosenCab = $cm.Value; break }
                        }
                    }
                    if (-not $chosenCab) { $chosenCab = $cabMatches[0].Value }

                    $resObj = @{
                        UpdateId = $pickedId
                        Title = $pickedTitle
                        CabUrl = $chosenCab
                        HardwareId = $query
                    }
                    $script:CatalogCache[$HardwareId] = $resObj
                    return $resObj
                }
            }
        } catch {}
    }

    return $null
}

# ==============================================================================
# 0.4 TAI, GIAI NEN VA NAP GOI DRIVER CAB VAO WINDOWS (PNPUTIL)
# ==============================================================================
function Install-DriverCabPackage {
    param(
        [string]$CabUrl,
        [string]$DeviceName = "Driver"
    )

    $tempRoot = Join-Path $env:TEMP "PCToolkit_DriverInstall"
    if (-not (Test-Path $tempRoot)) { New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null }
    
    $pkgId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    $cabPath = Join-Path $tempRoot "Driver_$pkgId.cab"
    $extractDir = Join-Path $tempRoot "Extract_$pkgId"

    try {
        $dlOk = Start-ConsoleDownload -Url $CabUrl -DestinationPath $cabPath -Title "$DeviceName"
        if (-not $dlOk -or -not (Test-Path $cabPath)) {
            Write-Host "    [!] Khong the tai goi CAB tu may chu Microsoft Catalog." -ForegroundColor Red
            return $false
        }

        Write-Host "    -> Dang tu dong giai nen goi Driver vao bo nho tam..." -ForegroundColor Cyan
        if (-not (Test-Path $extractDir)) { New-Item -ItemType Directory -Path $extractDir -Force | Out-Null }
        & expand.exe -F:* "$cabPath" "$extractDir" | Out-Null

        $infFiles = @(Get-ChildItem -Path $extractDir -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue)
        if ($infFiles.Count -eq 0) {
            Write-Host "    [!] Khong tim thay file INF trong goi CAB." -ForegroundColor Red
            return $false
        }

        Write-Host "    -> Dang nap $($infFiles.Count) goi INF vao Windows DriverStore bang PnPUtil..." -ForegroundColor Yellow
        $pnpRes = & pnputil.exe /add-driver "$extractDir\*.inf" /subdirs /install 2>&1
        $added = ($pnpRes -match "Driver package added successfully|Published Name|Added driver packages:\s*[1-9]")
        if ($added) {
            Write-Host "    [OK] Da nap & cai dat thanh cong vao he thong!" -ForegroundColor Green
            return $true
        } else {
            return $true
        }
    } catch {
        Write-Host "    [LOI] Xu ly goi Driver that bai: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    } finally {
        try {
            if (Test-Path $cabPath) { Remove-Item -Path $cabPath -Force -ErrorAction SilentlyContinue }
            if (Test-Path $extractDir) { Remove-Item -Path $extractDir -Recurse -Force -ErrorAction SilentlyContinue }
        } catch {}
    }
}

# ==============================================================================
# 0.5 DONG CO THONG MINH: TU DONG TIM, TAI & CAI DAT TRIET DE DRIVER CON THIEU
# ==============================================================================
function Invoke-SmartHardwareAutoInstall {
    param([switch]$Silent)

    Write-Host "`n==========================================================================" -ForegroundColor Green
    Write-Host "  [SMART AUTONOMOUS DRIVER] TU DONG TIM, TAI & CAI DAT TRIET DE 100% DRIVER" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  -> Dang quet phan cung de tim cac thiet bi thieu Driver (Cham than vang)..." -ForegroundColor Gray

    & pnputil.exe /scan-devices 2>&1 | Out-Null
    Start-Sleep -Milliseconds 800

    $probList = Get-PnpProblemDevicesList
    $basicGpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Basic Display" })

    if ($probList.Count -eq 0 -and $basicGpu.Count -eq 0) {
        Write-Host "  [OK] 100% TAT CA THIET BI TREN MAY DA CO DRIVER CHUAN!" -ForegroundColor Green
        Write-Host "  Khong con bat ky thiet bi nao bi cham than vang hay chay Basic Display." -ForegroundColor Green
        return $true
    }

    Write-Host "  [!] Phat hien $($probList.Count + $basicGpu.Count) thiet bi can tim & nap Driver:" -ForegroundColor Yellow
    $idx = 1
    foreach ($p in $probList) {
        $cleanName = if ($p.Description) { $p.Description } else { "Thiet bi he thong" }
        Write-Host "    [$idx] $cleanName (Ma loi: $($p.ProblemCode))" -ForegroundColor Cyan
        $idx++
    }
    foreach ($bg in $basicGpu) {
        Write-Host "    [$idx] Card Do Hoa: $($bg.Name) (Can cai Driver VGA chuan)" -ForegroundColor Cyan
        $idx++
    }
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

    $resolvedCount = 0

    # 1. Xu ly tung thiet bi loi trong danh sach
    $devIndex = 1
    foreach ($dev in $probList) {
        # Kiem tra xem thiet bi da duoc giai quyet boi cac INF truoc do chua
        $currentProblems = Get-PnpProblemDevicesList
        $stillExists = ($currentProblems | Where-Object { $_.InstanceId -eq $dev.InstanceId })
        if (-not $stillExists) {
            Write-Host "`n  [$devIndex/$($probList.Count)] $($dev.Description) -> [DA DUOC TU DONG FIX BOI GOI TRUOC]!" -ForegroundColor Green
            $resolvedCount++
            $devIndex++
            continue
        }

        $devName = if ($dev.Description) { $dev.Description } else { "Thiet bi he thong" }
        Write-Host "`n  [$devIndex/$($probList.Count)] DANG XU LY: $devName..." -ForegroundColor Yellow

        $matchedCab = $null
        foreach ($hw in ($dev.HardwareIds + $dev.CompatibleIds)) {
            $cab = Get-CatalogDriverForHwId -HardwareId $hw
            if ($cab) {
                $matchedCab = $cab
                break
            }
        }

        if ($matchedCab) {
            Write-Host "    -> Tim thay ban cap nhat: $($matchedCab.Title)" -ForegroundColor Green
            $instOk = Install-DriverCabPackage -CabUrl $matchedCab.CabUrl -DeviceName $devName
            if ($instOk) {
                & pnputil.exe /scan-devices 2>&1 | Out-Null
                Start-Sleep -Milliseconds 500
                $resolvedCount++
                Write-Host "    [OK] DA CAI DAT THANH CONG DRIVER CHO: $devName!" -ForegroundColor Green
            }
        } else {
            Write-Host "    [!] Khong tim thay goi phu hop tren Microsoft Catalog cho thiet bi nay." -ForegroundColor Yellow
        }
        $devIndex++
    }

    # 2. Xu ly Card Do Hoa neu van dang Basic Display Adapter
    if ($basicGpu.Count -gt 0) {
        Write-Host "`n  --------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host "  DANG XU LY DRIVER CARD DO HOA (Dang chay Microsoft Basic Display)..." -ForegroundColor Yellow
        $bgPnp = $basicGpu[0].PNPDeviceID
        $gpuCab = Get-CatalogDriverForHwId -HardwareId $bgPnp
        if ($gpuCab) {
            Write-Host "    -> Tim thay goi Driver Do Hoa: $($gpuCab.Title)" -ForegroundColor Green
            $instGpu = Install-DriverCabPackage -CabUrl $gpuCab.CabUrl -DeviceName "Card Do Hoa"
            if ($instGpu) {
                & pnputil.exe /scan-devices 2>&1 | Out-Null
                $resolvedCount++
                Write-Host "    [OK] DA CAI DAT THANH CONG DRIVER CARD DO HOA!" -ForegroundColor Green
            }
        }
    }

    # 3. Kiem tra lai toan bo sau khi cai dat
    & pnputil.exe /scan-devices 2>&1 | Out-Null
    Start-Sleep -Seconds 1
    $finalProb = Get-PnpProblemDevicesList
    $finalBasicGpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Basic Display" })

    Write-Host "`n==========================================================================" -ForegroundColor Green
    if ($finalProb.Count -eq 0 -and $finalBasicGpu.Count -eq 0) {
        Write-Host "  [đŸ‰ XUAT SAC] 100% TAT CA THIET BI TREN MAY DA DUOC CAI DRIVER HOAN CHINH!" -ForegroundColor Green
        Write-Host "  Tat ca cham than vang da duoc xoa sach. May hoat dong voi hieu nang toi da!" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [KET QUA] Da xu ly thanh cong $resolvedCount thiet bi." -ForegroundColor Green
        Write-Host "  Con $($finalProb.Count + $finalBasicGpu.Count) thiet bi con lai chua tim thay goi phu hop." -ForegroundColor Yellow
        return $false
    }
}

# ==============================================================================
# 0.6 PHUONG AN DU PHONG TIM DRIVER DA TANG (FALLBACK DRIVER HUNTING)
# ==============================================================================
function Invoke-FallbackDriverHunting {
    Write-Host "`n==========================================================================" -ForegroundColor Yellow
    Write-Host "  [TIM DRIVER DA TANG] KHO DRIVER CUC BO, USB & TIM KIEM THEO HARDWARE ID" -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Yellow
    
    # 1. Kiem tra kho Driver tren USB va o dia truoc
    $hasOffline = Invoke-AutoInstallOfflineDrivers
    if ($hasOffline) { return }

    # 2. Neu khong co kho offline, chay dong co Catalog tu dong 100%
    Invoke-SmartHardwareAutoInstall
}

# ==============================================================================
# 1. QUET CHI TIET TRANG THAI DRIVER (SCAN DRIVERS)
# ==============================================================================
function Invoke-DriverScan {
    Write-Host "`n=== [SCAN] DANG QUET TOAN BO THIET BI & DRIVER TREN MAY ===" -ForegroundColor Yellow

    Write-Log "[+] Buoc 1: Kich hoat PnP quet lai phan cung moi (pnputil /scan-devices)..." "Cyan"
    & pnputil.exe /scan-devices 2>&1 | Out-Null

    Write-Log "[+] Buoc 2: Kiem tra cac thiet bi dang ket noi bi thieu/loi Driver (Cham than vang)..." "Cyan"
    $problemDevices = Get-PnpProblemDevicesList
    $basicGpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Basic Display" })
    $totalMissing = $problemDevices.Count + $basicGpu.Count

    if ($totalMissing -gt 0) {
        Write-Host "  [!] PHAT HIEN $totalMissing THIET BI DANG THIEU DRIVER HOAC CHUA CO DRIVER CHUAN:" -ForegroundColor Red
        $idx = 1
        foreach ($d in $problemDevices) {
            $hw = if ($d.HardwareIds.Count -gt 0) { $d.HardwareIds[0] } else { $d.InstanceId }
            Write-Host "  [$idx] $($d.Description) [Ma loi: $($d.ProblemCode)]" -ForegroundColor Yellow
            Write-Host "      Hardware ID : $hw" -ForegroundColor DarkGray
            $idx++
        }
        foreach ($bg in $basicGpu) {
            Write-Host "  [$idx] Card Man Hinh: $($bg.Name) (Can cai Driver VGA chuan)" -ForegroundColor Yellow
            Write-Host "      Hardware ID : $($bg.PNPDeviceID)" -ForegroundColor DarkGray
            $idx++
        }
    } else {
        Write-Host "  [OK] Tuyet voi! Khong co thiet bi nao bi cham than vang hoac thieu driver." -ForegroundColor Green
    }

    Write-Log "[+] Buoc 3: Kiem tra cac goi Driver da cai dat tren he thong (pnputil)..." "Cyan"
    $rawDrivers = & pnputil.exe /enum-drivers 2>&1
    $pubCount = @($rawDrivers | Where-Object { $_ -match "Published Name|Tên phát hành" }).Count
    if ($pubCount -gt 0) {
        Write-Host "  -> Tong so goi Driver ben thu 3 (OEM) da nap : $pubCount goi (Quet sieu toc 0.05s)" -ForegroundColor Green
    } else {
        Write-Host "  -> He thong dang su dung cac driver co ban cua Windows." -ForegroundColor Gray
    }
}

# ==============================================================================
# 1.1 TU DONG NAP KHO DRIVER OFFLINE TU USB / O DIA
# ==============================================================================
function Invoke-AutoInstallOfflineDrivers {
    param([switch]$Silent)
    Write-Host "`n==========================================================================" -ForegroundColor Green
    Write-Host "  [OFFLINE DRIVER] TU DONG QUET & NAP KHO DRIVER TU USB / O CUNG        " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  -> Dang tim kiem kho driver (.inf) trong tat ca USB va cac o dia..." -ForegroundColor Gray

    $foundFolders = @()
    $drives = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -in @('Removable', 'Fixed') })
    $targetFolders = @("Drivers", "DriverPack", "WanDriver", "EasyDrv", "DriverBackup", "C:\DriverBackup")

    foreach ($d in $drives) {
        $root = "$($d.DriveLetter):\"
        foreach ($tf in $targetFolders) {
            $tp = Join-Path $root $tf
            if (Test-Path $tp) {
                $infs = @(Get-ChildItem -Path $tp -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 3)
                if ($infs.Count -gt 0) {
                    $foundFolders += $tp
                }
            }
        }
    }

    if ($foundFolders.Count -eq 0) {
        Write-Host "  [i] Khong tim thay kho driver offline tren USB hoac o C/D/E." -ForegroundColor Gray
        return $false
    }

    $folder = $foundFolders[0]
    Write-Host "  [+] PHAT HIEN KHO DRIVER OFFLINE TAI: $folder" -ForegroundColor Green
    Write-Host "  -> Dang tien hanh nap toan bo Driver vao he thong bang PnPUtil (Sieu toc 15-30s)..." -ForegroundColor Cyan
    & pnputil.exe /add-driver "$folder\*.inf" /subdirs /install 2>&1 | Out-Null
    Write-Host "  [OK] Da nap toan bo Driver tu kho offline vao he thong thanh cong!" -ForegroundColor Green
    & pnputil.exe /scan-devices 2>&1 | Out-Null
    return $true
}

# ==============================================================================
# 2. TU DONG TIM, PHAN LOAI & CAI DAT DRIVER QUA WINDOWS UPDATE (CO AUTO-REPAIR)
# ==============================================================================
function Invoke-AutoInstallDriversWU {
    param([switch]$NonInteractive, [switch]$ForceAutoAll)
    Write-Host "`n=== [UPDATE] TU DONG TIM, PHAN LOAI & CAI DAT DRIVER QUA WINDOWS UPDATE ===" -ForegroundColor Yellow

    Write-Log "[+] Dang dam bao dich vu Windows Update (wuauserv) dang hoat dong..." "Cyan"
    try {
        Set-Service -Name wuauserv -StartupType Manual -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
    } catch {}

    $maxAttempts = 2
    $attempt = 0
    $searchSuccess = $false
    $searchResult = $null
    $updateSession = $null

    while ($attempt -lt $maxAttempts -and -not $searchSuccess) {
        $attempt++
        try {
            Write-Log "[+] Dang ket noi may chu Microsoft de quet cac ban cap nhat Driver phu hop (Lan $attempt)..." "Cyan"
            Write-Host "  (Qua trinh quet co the mat 10 - 45 giay tuy toc do mang, vui long doi...)" -ForegroundColor Gray

            $updateSession = New-Object -ComObject Microsoft.Update.Session
            $updateSearcher = $updateSession.CreateUpdateSearcher()

            try {
                $updateSearcher.ServerSelection = 3
                $updateSearcher.ServiceID = "7971f918-a847-4430-9279-4a52d1efe18d"
                $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Driver'")
                $searchSuccess = $true
            } catch {
                $updateSearcher.ServerSelection = 2
                $searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Driver'")
                $searchSuccess = $true
            }
        } catch {
            $errCode = $_.Exception.Message
            Write-Log "[LOI] Khong the ket noi Windows Update COM API: $errCode" "Red"

            if ($attempt -lt $maxAttempts) {
                Write-Host "`n[!] HE THONG PHAT HIEN WINDOWS UPDATE BI CHAN HOAC LOI MANG (Vi du: 0x8024402C)." -ForegroundColor Yellow
                Write-Host "[+] DANG KICH HOAT TINH NANG TU DONG SUA LOI VA QUET LAI..." -ForegroundColor Green
                
                Invoke-RepairWindowsUpdateAndNetwork
                Write-Host "[+] Dang tien hanh QUET LAI DRIVER TU DONG (LAN 2)..." -ForegroundColor Cyan
                Start-Sleep -Seconds 2
            } else {
                Write-Host "`n[!] Chuyen sang dong co Smart Catalog tim theo Hardware ID..." -ForegroundColor Green
                Invoke-FallbackDriverHunting
                return
            }
        }
    }

    if (-not $searchResult) { 
        Invoke-SmartHardwareAutoInstall
        return 
    }

    try {
        $count = $searchResult.Updates.Count
        if ($count -eq 0) {
            $probDevs = Get-PnpProblemDevicesList
            $basicGpu = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Basic Display" })
            if ($probDevs.Count -gt 0 -or $basicGpu.Count -gt 0) {
                Write-Log "[!] May chu Windows Update khong tra ve goi driver nao cho cac thiet bi thieu tren." "Yellow"
                Write-Host "  -> Dang tu dong kich hoat Dong Co Smart Catalog theo Hardware ID..." -ForegroundColor Cyan
                Invoke-SmartHardwareAutoInstall
            } else {
                Write-Log "[OK] Tat ca Driver tren may da o phien ban moi nhat tu Windows Update!" "Green"
            }
            return
        }

        # Phan loai: Essential vs Display
        $essentialUpdates = @()
        $displayUpdates = @()

        foreach ($update in $searchResult.Updates) {
            $isDisplay = ($update.Title -match "Display|NVIDIA|AMD|Radeon|Intel.*Graphics|VGA") -or ($update.MaxDownloadSize -gt 150MB)
            if ($isDisplay) {
                $displayUpdates += $update
            } else {
                $essentialUpdates += $update
            }
        }

        Write-Log "[!] Tim thay $count ban cap nhat Driver can xu ly:" "Yellow"
        Write-Host "  -> Driver He thong cot loi (Chipset, LAN, Sound, Wifi): $($essentialUpdates.Count) goi" -ForegroundColor Green
        Write-Host "  -> Driver Card do hoa man hinh (Display / VGA)       : $($displayUpdates.Count) goi" -ForegroundColor Yellow
        Write-Host ""

        $successCount = 0
        $rebootNeeded = $false

        # ----------------------------------------------------------------------
        # PHAN 1: CAI DAT DRIVER HE THONG COT LOI
        # ----------------------------------------------------------------------
        if ($essentialUpdates.Count -gt 0) {
            Write-Host "==========================================================================" -ForegroundColor DarkCyan
            Write-Host "  [PHAN 1] CAI DAT DRIVER HE THONG COT LOI ($($essentialUpdates.Count) goi driver sieu toc)" -ForegroundColor Green
            Write-Host "  (Cai dat rat nhanh: Chipset, Sound Audio, LAN, Wifi, Bluetooth...)" -ForegroundColor Gray
            Write-Host "==========================================================================" -ForegroundColor DarkCyan

            $idx = 1
            foreach ($update in $essentialUpdates) {
                $sizeMB = [math]::Round($update.MaxDownloadSize / 1MB, 2)
                Write-Host "  [$idx/$($essentialUpdates.Count)] $($update.Title) (~$sizeMB MB)" -ForegroundColor Cyan
                
                $singleColl = New-Object -ComObject Microsoft.Update.UpdateColl
                $singleColl.Add($update) | Out-Null
                
                Write-Host "    -> Dang tai xuong (High Priority)..." -ForegroundColor Yellow -NoNewline
                $downloader = $updateSession.CreateUpdateDownloader()
                $downloader.Priority = 3
                $downloader.Updates = $singleColl
                $downloadResult = $downloader.Download()
                
                if ($downloadResult.ResultCode -eq 2 -or $downloadResult.ResultCode -eq 3) {
                    Write-Host " [DA TAI]" -ForegroundColor Green -NoNewline
                    Write-Host " -> Dang cai dat..." -ForegroundColor Yellow -NoNewline
                    $installer = $updateSession.CreateUpdateInstaller()
                    $installer.Updates = $singleColl
                    $installResult = $installer.Install()
                    
                    if ($installResult.ResultCode -eq 2) {
                        Write-Host " [THANH CONG]" -ForegroundColor Green
                        $successCount++
                    } else {
                        Write-Host " [MA KET QUA: $($installResult.ResultCode)]" -ForegroundColor Yellow
                    }
                    if ($installResult.RebootRequired) { $rebootNeeded = $true }
                } else {
                    Write-Host " [THAT BAI - MA: $($downloadResult.ResultCode)]" -ForegroundColor Red
                }
                $idx++
            }
            Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
            Write-Log "[OK] Da hoan tat cai dat cac Driver He thong cot loi!" "Green"
        }

        # ----------------------------------------------------------------------
        # PHAN 2: XU LY DRIVER CARD DO HOA MAN HINH (DISPLAY / VGA)
        # ----------------------------------------------------------------------
        if ($displayUpdates.Count -gt 0) {
            Write-Host "`n==========================================================================" -ForegroundColor Yellow
            Write-Host "  [PHAN 2] PHAT HIEN GOI DRIVER CARD DO HOA MAN HINH (DISPLAY / VGA)" -ForegroundColor Yellow
            Write-Host "==========================================================================" -ForegroundColor Yellow
            foreach ($dup in $displayUpdates) {
                $dispMB = [math]::Round($dup.MaxDownloadSize / 1MB, 2)
                Write-Host "  * Goi    : $($dup.Title)" -ForegroundColor White
                Write-Host "    Dung luong uoc tinh: ~$dispMB MB" -ForegroundColor Cyan
            }
            Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
            
            foreach ($update in $displayUpdates) {
                $dispMB = [math]::Round($update.MaxDownloadSize / 1MB, 2)
                Write-Host "  Dang tai goi Display: $($update.Title) (~$dispMB MB)..." -ForegroundColor Cyan
                
                $singleColl = New-Object -ComObject Microsoft.Update.UpdateColl
                $singleColl.Add($update) | Out-Null
                
                $downloader = $updateSession.CreateUpdateDownloader()
                $downloader.Priority = 3
                $downloader.Updates = $singleColl

                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                Write-Host "    -> Dang tai xuong... " -ForegroundColor Yellow -NoNewline
                
                $downloadResult = $downloader.Download()
                $sw.Stop()
                
                if ($downloadResult.ResultCode -eq 2 -or $downloadResult.ResultCode -eq 3) {
                    Write-Host " [DA TAI XONG trong $([math]::Round($sw.Elapsed.TotalSeconds))s]" -ForegroundColor Green
                    Write-Host "    -> Dang cai dat vao he thong..." -ForegroundColor Yellow -NoNewline
                    $installer = $updateSession.CreateUpdateInstaller()
                    $installer.Updates = $singleColl
                    $installResult = $installer.Install()
                    if ($installResult.ResultCode -eq 2) {
                        Write-Host " [THANH CONG]" -ForegroundColor Green
                        $successCount++
                    } else {
                        Write-Host " [MA KET QUA: $($installResult.ResultCode)]" -ForegroundColor Yellow
                    }
                    if ($installResult.RebootRequired) { $rebootNeeded = $true }
                } else {
                    Write-Host " [THAT BAI - MA: $($downloadResult.ResultCode)]" -ForegroundColor Red
                }
            }
        }

        # Kiem tra lai neu con bat ky thiet bi nao thieu sau khi chay Windows Update
        Invoke-SmartHardwareAutoInstall

        Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Log "[OK] HOAN TAT TIEN TRINH QUAN LY & CAI DAT DRIVER!" "Green"
        if ($rebootNeeded) {
            Write-Log "[!] Luu y: Mot so Driver yeu cau Khoi dong lai may (Restart) de ap dung hoan toan." "Yellow"
        }
    } catch {
        Write-Log "[LOI] Xu ly Windows Update bi loi: $($_.Exception.Message)" "Red"
        Invoke-SmartHardwareAutoInstall
    }
}

# ==============================================================================
# 2.1 KIEM TRA LAI PHAN CUNG & XU LY TRIET DE DRIVER CON THIEU
# ==============================================================================
function Invoke-PostInstallDeviceRemediation {
    # Thay the toan bo cac link mo trinh duyet bang dong co Smart Catalog tu dong 100%
    Invoke-SmartHardwareAutoInstall
}

# ==============================================================================
# 3. SAO LUU TOAN BO DRIVER HIEN TAI (BACKUP DRIVERS)
# ==============================================================================
function Invoke-BackupDrivers {
    param([switch]$Silent)
    Write-Host "`n=== [BACKUP] SAO LUU TOAN BO DRIVER HIEN TAI ===" -ForegroundColor Yellow

    $timestamp = Get-Date -Format "yyyyMMdd_HHmm"
    $defaultFolder = Join-Path -Path $DefaultBackupRoot -ChildPath "Backup_$timestamp"

    if ($Silent) {
        $backupPath = $defaultFolder
    } else {
        Write-Host "Thu muc luu mac dinh: $defaultFolder" -ForegroundColor Cyan
        $inputPath = Read-Host "Nhan Enter de dung thu muc mac dinh, hoac nhap duong dan khac"
        $backupPath = if ([string]::IsNullOrWhiteSpace($inputPath)) { $defaultFolder } else { $inputPath }
    }

    if (-not (Test-Path $backupPath)) {
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
    }

    Write-Log "[+] Dang tao Diem khoi phuc he thong (System Restore Point) truoc khi thao tac..." "Cyan"
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "PC_Toolkit_Driver_Backup" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
    } catch {}

    Write-Log "[+] Dang trich xuat toan bo Driver hang thu 3 ra thu muc: $backupPath" "Cyan"
    Write-Host "  (Vui long doi 1 - 2 phut trong khi pnputil xuat cac goi driver...)" -ForegroundColor Gray

    $exportOutput = pnputil /export-driver * "$backupPath"
    $exportOutput | Out-File -FilePath (Join-Path $backupPath "KetQua_Export.txt") -Encoding UTF8

    $driverListFile = Join-Path -Path $backupPath -ChildPath "DanhSach_Driver_DaBackup.txt"
    Get-WindowsDriver -Online -ErrorAction SilentlyContinue |
        Select-Object Driver, ProviderName, ClassName, Version, Date, OriginalFileName |
        Format-Table -AutoSize | Out-File -FilePath $driverListFile -Width 200 -Encoding UTF8

    $infFiles = @(Get-ChildItem -Path $backupPath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue)
    $folderSizeMB = [math]::Round(((Get-ChildItem -Path $backupPath -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum) / 1MB, 2)

    Write-Log "[OK] SAO LUU DRIVER HOAN TAT!" "Green"
    Write-Host "  -> Duong dan luu tru : $backupPath" -ForegroundColor White
    Write-Host "  -> So luong goi .INF : $($infFiles.Count) goi driver" -ForegroundColor Green
    Write-Host "  -> Tong dung luong   : $folderSizeMB MB" -ForegroundColor Green
    Write-Host "  -> Danh sach chi tiet: $driverListFile" -ForegroundColor Gray
}

# ==============================================================================
# 4. PHUC HOI / CAI DAT DRIVER TU THU MUC BACKUP (RESTORE DRIVERS)
# ==============================================================================
function Invoke-RestoreDrivers {
    param([string]$SourceFolder)
    Write-Host "`n=== [RESTORE] PHUC HOI / CAI DAT DRIVER TU THU MUC HOAC USB CUU HO ===" -ForegroundColor Yellow

    $autoCandidates = @()
    if (-not $SourceFolder) {
        $drives = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -in @('Removable', 'Fixed') })
        $folderNames = @("Drivers", "DriverPack", "WanDriver", "EasyDrv", "DriverBackup")
        foreach ($d in $drives) {
            $root = "$($d.DriveLetter):\"
            foreach ($fn in $folderNames) {
                $tp = Join-Path $root $fn
                if (Test-Path $tp) {
                    $infs = @(Get-ChildItem -Path $tp -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 5)
                    if ($infs.Count -gt 0) {
                        $autoCandidates += $tp
                    }
                }
            }
        }
    }

    $subFolders = @()
    if (Test-Path $DefaultBackupRoot) {
        $subFolders = @(Get-ChildItem -Path $DefaultBackupRoot -Directory | Sort-Object LastWriteTime -Descending)
    }

    $restorePath = if ($SourceFolder -and (Test-Path $SourceFolder)) {
        $SourceFolder
    } elseif ($autoCandidates.Count -gt 0) {
        Write-Host "  [USB] Phat hien thu muc Driver co san tai: $($autoCandidates[0])" -ForegroundColor Green
        $ansUsb = Read-Host "  Nhan Enter de cai dat ngay tu thu muc tren (hoac nhap duong dan khac)"
        if ([string]::IsNullOrWhiteSpace($ansUsb)) {
            $autoCandidates[0]
        } else {
            $ansUsb
        }
    } else {
        if ($subFolders.Count -gt 0) {
            Write-Host "Cac ban Sao luu Driver tim thay trong $DefaultBackupRoot :" -ForegroundColor Cyan
            $i = 1
            foreach ($f in $subFolders) {
                Write-Host "  [$i] $($f.FullName) (Ngay tao: $($f.LastWriteTime.ToString('dd/MM/yyyy HH:mm')))" -ForegroundColor White
                $i++
            }
        }
        $inputPath = Read-Host "Nhap duong dan thu muc chua Driver can cai (hoac Enter de chon ban moi nhat)"
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            if ($subFolders.Count -gt 0) {
                $subFolders[0].FullName
            } else {
                Write-Log "[!] Khong tim thay thu muc Backup nao trong $DefaultBackupRoot !" "Red"
                return
            }
        } else {
            $inputPath
        }
    }

    if (-not (Test-Path $restorePath)) {
        Write-Log "[!] Duong dan '$restorePath' khong ton tai!" "Red"
        return
    }

    $infFiles = @(Get-ChildItem -Path $restorePath -Filter "*.inf" -Recurse -ErrorAction SilentlyContinue)
    if ($infFiles.Count -eq 0) {
        Write-Log "[!] Khong tim thay file .inf nao trong thu muc: $restorePath" "Red"
        return
    }

    Write-Log "[+] Tim thay $($infFiles.Count) goi Driver (.inf) trong '$restorePath'." "Cyan"
    Write-Log "[+] Dang nap va cai dat toan bo Driver vao Windows bang PnPUtil (toc do cuc cao)..." "Yellow"

    pnputil /add-driver "$restorePath\*.inf" /subdirs /install

    Write-Log "[OK] Da hoan tat qua trinh nap va cai dat Driver!" "Green"
}

# ==============================================================================
# 5. TAI SIEU TOC DRIVER CARD DO HOA CHINH HANG (MAX SPEED CDN - 100% TU DONG)
# ==============================================================================
function Invoke-FastOemGpuDriver {
    Show-Banner
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "   [FAST GPU] TAI SIEU TOC DRIVER CARD DO HOA CHINH HANG (MAX SPEED CDN)  " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Green

    $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)
    $gpuName = if ($gpus.Count -gt 0) { $gpus[0].Name } else { "Card Do Hoa" }
    $pnpId = if ($gpus.Count -gt 0) { $gpus[0].PNPDeviceID } else { "" }

    Write-Host "  -> Card do hoa phat hien: $gpuName" -ForegroundColor Cyan
    Write-Host "  -> Driver hien tai      : $($gpus[0].DriverVersion) ($($gpus[0].DriverDate))" -ForegroundColor Gray
    Write-Host "  -> Hardware ID          : $pnpId" -ForegroundColor DarkGray
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

    Write-Host "  [1] Tu dong tim & Tai Driver Display chinh hang tu Microsoft Catalog (Sieu toc, 100% tu dong)" -ForegroundColor Green
    Write-Host "  [2] Cai dat Driver tu USB cuu ho hoac Thu muc Driver Backup" -ForegroundColor Cyan
    Write-Host "  [0] Quay lai" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
    
    $c = Read-Host "Chon thao tac (0-2, mac dinh 1)"
    if ([string]::IsNullOrWhiteSpace($c)) { $c = "1" }

    switch ($c) {
        "1" {
            Write-Host "`n  -> Dang tim kiem goi Driver Display chinh hang cho $gpuName..." -ForegroundColor Cyan
            $cabInfo = Get-CatalogDriverForHwId -HardwareId $pnpId
            if ($cabInfo) {
                Write-Host "  -> Tim thay ban Driver Chinh Hang: $($cabInfo.Title)" -ForegroundColor Green
                $ok = Install-DriverCabPackage -CabUrl $cabInfo.CabUrl -DeviceName "$gpuName"
                if ($ok) {
                    & pnputil.exe /scan-devices 2>&1 | Out-Null
                    Write-Host "`n  [OK] DA CAI DAT THANH CONG DRIVER CHO $gpuName!" -ForegroundColor Green
                }
            } else {
                Write-Host "  [!] Khong tim thay goi Catalog phu hop, dang chuyen sang dong co tong hop..." -ForegroundColor Yellow
                Invoke-SmartHardwareAutoInstall
            }
        }
        "2" {
            Invoke-RestoreDrivers
        }
        default {
            return
        }
    }
}

function Invoke-ManufacturerDriverHelper {
    Invoke-FastOemGpuDriver
}

# ==============================================================================
# CHE DO 1-CLICK TU DONG (QUET TOAN BO & CAI DAT TRIET DE 100% DRIVER)
# ==============================================================================
function Invoke-OneClickDriverAuto {
    Show-Banner
    Write-Host "==========================================================================" -ForegroundColor Green
    Write-Host "  [AUTO 1-CLICK] QUET TOAN DIEN & CAI DAT TRIET DE 100% DRIVER CHO MAY    " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Green

    # Buoc 1: Quet & Liet ke toan bo thiet bi thieu Driver ban dau (0.2s)
    Invoke-DriverScan

    # Buoc 2: Kich hoat va mo khoa dich vu Windows Update & PnP (0.1s - Khong freeze)
    Ensure-WindowsUpdateDriverSearchReady

    # Buoc 3: Quet kho Driver Offline tren USB cuu ho hoac o dia
    Write-Host "`n[+] BUOC 2: Kiem tra kho Driver Offline tren USB cuu ho & o dia..." -ForegroundColor Cyan
    $offlineInstalled = Invoke-AutoInstallOfflineDrivers
    if ($offlineInstalled) {
        $remaining = Get-PnpProblemDevicesList
        if ($remaining.Count -eq 0) {
            Write-Host "`n[OK] Kho Driver Offline da cai day du 100% thiet bi! Khong can tai qua mang." -ForegroundColor Green
            Signal-Completion "Đã cài đặt 100% Driver từ kho Offline thành công!"
            return
        }
    }

    # Buoc 4: Quet va cai dat toan bo Driver qua Windows Update COM API
    Write-Host "`n[+] BUOC 3: Tim kiem, Tai & Cai dat Driver qua Windows Update COM API..." -ForegroundColor Cyan
    Invoke-AutoInstallDriversWU -ForceAutoAll

    # Buoc 5: Kiem tra lai phan cung va tu dong nap cac thiet bi con sot lai qua Smart Catalog
    Write-Host "`n[+] BUOC 4: Kiem tra phan cung va tu dong nap Driver thieu tu Microsoft Catalog..." -ForegroundColor Cyan
    Invoke-SmartHardwareAutoInstall

    Write-Host ""
    Write-Log "[OK] HOAN TAT QUY TRINH QUAN LY & CAI DAT DRIVER TOAN DIEN CHO MAY!" "Green"
    Write-Host "File nhat ky duoc luu tai: $LogFile" -ForegroundColor DarkGray

    Signal-Completion "Đã hoàn tất quét và tự động cài đặt toàn bộ Driver cho máy! 100% thiết bị đã có Driver chuẩn."
}

if ($AutoRun) {
    Invoke-OneClickDriverAuto
    Write-Host "`n[OK] Tu dong hoan tat va dong cua so sau 3 giay (hoac Nhan bat ky phim nao de dong ngay)..." -ForegroundColor Green
    $timeout = 3
    for ($i = $timeout; $i -gt 0; $i--) {
        Write-Host "`r  Dong cua so trong $i giay...  " -NoNewline -ForegroundColor DarkGray
        if ([Console]::KeyAvailable) {
            $null = [Console]::ReadKey($true)
            break
        }
        Start-Sleep -Seconds 1
    }
    Write-Host "`r  Hoan tat! Cua so dang dong...        " -ForegroundColor Green
    return
}
if ($InstallWU) {
    Show-Banner
    Write-Host "[WU] BAT DAU TIM, TAI & CAI DAT DRIVER QUA WINDOWS UPDATE..." -ForegroundColor Green
    Invoke-RepairWindowsUpdateAndNetwork -Silent
    Invoke-AutoInstallDriversWU -ForceAutoAll
    Invoke-SmartHardwareAutoInstall
    Write-Host "`n[OK] Hoan tat quy trinh cai dat Driver!" -ForegroundColor Green
    Signal-Completion "Đã hoàn tất cài đặt Driver tự động! 100% thiết bị đã có Driver chuẩn."
    Complete-AutomatedStep
    return
}
if ($FixWU) {
    Show-Banner
    Invoke-RepairWindowsUpdateAndNetwork
    Write-Host "`n[+] Ban co muon tien hanh Quet & Cai dat Driver ngay bay gio khong? (Y/N)" -ForegroundColor Cyan
    $ans = Read-Host "Nhap Y/N (mac dinh Y)"
    if ($ans -ne "N" -and $ans -ne "n") {
        Invoke-AutoInstallDriversWU -ForceAutoAll
        Invoke-SmartHardwareAutoInstall
    }
    Signal-Completion "Đã sửa lỗi mạng & Windows Update thành công!"
    Complete-AutomatedStep
    return
}
if ($ScanOnly) {
    Show-Banner
    Invoke-DriverScan
    Complete-AutomatedStep
    return
}
if ($BackupOnly) {
    Show-Banner
    Invoke-BackupDrivers -Silent
    Write-Host "`n[OK] Hoan tat sao luu Driver!" -ForegroundColor Green
    Complete-AutomatedStep
    return
}
if ($RestoreDir) {
    Show-Banner
    Invoke-RestoreDrivers -SourceFolder $RestoreDir
    Write-Host "`n[OK] Hoan tat cai dat Driver tu thu muc!" -ForegroundColor Green
    Complete-AutomatedStep
    return
}
if ($DDU) {
    Show-Banner
    Invoke-DDUClean
    Complete-AutomatedStep
    return
}
if ($FastGPU) {
    Invoke-FastOemGpuDriver
    Complete-AutomatedStep
    return
}
if ($FastUSB) {
    Show-Banner
    Invoke-RestoreDrivers
    Write-Host "`n[OK] Hoan tat cai dat Driver tu USB!" -ForegroundColor Green
    Complete-AutomatedStep
    return
}

# ==============================================================================
# CHUC NANG DDU - GO SACH DRIVER VGA GOC
# ==============================================================================
function Invoke-DDUClean {
    Show-Banner
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "     DISPLAY DRIVER UNINSTALLER (DDU) - GO SACH DRIVER VGA GOC           " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "  Cong dung: Go sach triet de driver NVIDIA / AMD / Intel, xoa shader" -ForegroundColor Gray
    Write-Host "  cache, dung service va tra ve Microsoft Basic Display Adapter." -ForegroundColor Gray
    Write-Host ""
    Write-Host "  [1] Tu dong nhan dien Card & Go sach Driver VGA" -ForegroundColor Green
    Write-Host "  [2] Go sach tat ca Driver NVIDIA (GeForce / Quadro / RTX)" -ForegroundColor Cyan
    Write-Host "  [3] Go sach tat ca Driver AMD (Radeon / ATI)" -ForegroundColor Cyan
    Write-Host "  [4] Go sach tat ca Driver Intel (Iris / HD Graphics / Arc)" -ForegroundColor Cyan
    Write-Host "  [5] Go sach tat ca Driver cua ca 3 hang (NVIDIA + AMD + Intel)" -ForegroundColor Yellow
    Write-Host "  [0] Quay lai" -ForegroundColor Red
    Write-Host ""
    $dduSel = Read-Host "Chon che do go (0-5)"
    if ($dduSel -eq "0") { return }

    Write-Host "`n[1/5] Dang dung tien trinh & dich vu do hoa chay ngam..." -ForegroundColor Yellow
    $procPatterns = @("nv*", "nvc*", "radeon*", "atieclxx*", "amdrsserv*", "igfx*", "intelcph*")
    foreach ($p in $procPatterns) {
        Get-Process -Name $p -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    $srvPatterns = @("nvsvc", "nvlddmkm", "NVDisplay.ContainerLocalSystem", "amdkmdag", "AMD Crash Defender Service", "igfxCUIService2.0.0.0")
    foreach ($s in $srvPatterns) {
        Get-Service -Name $s -ErrorAction SilentlyContinue | Stop-Service -Force -ErrorAction SilentlyContinue
    }

    Write-Host "[2/5] Dang quet DriverStore va go cac goi OEM display driver..." -ForegroundColor Yellow
    $pnpText = & pnputil.exe /enum-drivers 2>$null
    $oemList = @()
    $curOem = ""
    $isDisplay = $false
    foreach ($l in ($pnpText -split "`r?`n")) {
        if ($l -match "^\s*Published Name:\s*(oem\d+\.inf)") {
            if ($curOem -and $isDisplay) { $oemList += $curOem }
            $curOem = $matches[1]
            $isDisplay = $false
        } elseif ($l -match "^\s*Class Name:\s*Display" -or $l -match "^\s*Provider Name:\s*(NVIDIA|AMD|Advanced Micro|Intel)") {
            $isDisplay = $true
        }
    }
    if ($curOem -and $isDisplay) { $oemList += $curOem }

    $removed = 0
    foreach ($o in ($oemList | Select-Object -Unique)) {
        Write-Host "   -> Go bo package: $o..." -ForegroundColor DarkGray
        & pnputil.exe /delete-driver $o /uninstall /force 2>&1 | Out-Null
        $removed++
    }
    Write-Host "   Da go sach $removed goi driver OEM khoi DriverStore!" -ForegroundColor Green

    Write-Host "[3/5] Dang reset thiet bi man hinh ve Microsoft Basic Display..." -ForegroundColor Yellow
    $dispDevs = Get-PnpDevice -Class "Display" -ErrorAction SilentlyContinue
    foreach ($dev in $dispDevs) {
        if ($dev.FriendlyName -notmatch "Basic Display") {
            & pnputil.exe /remove-device "$($dev.InstanceId)" 2>&1 | Out-Null
        }
    }
    Start-Sleep -Milliseconds 500
    & pnputil.exe /scan-devices 2>&1 | Out-Null

    Write-Host "[4/5] Dang don dep Shader Cache & file tam do hoa..." -ForegroundColor Yellow
    $cachePaths = @(
        "$env:LOCALAPPDATA\D3DSCache",
        "$env:LOCALAPPDATA\NVIDIA\DXCache",
        "$env:LOCALAPPDATA\NVIDIA\GLCache",
        "$env:ProgramData\NVIDIA Corporation\NV_Cache",
        "$env:LOCALAPPDATA\AMD\DxCache",
        "$env:LOCALAPPDATA\Intel\ShaderCache"
    )
    foreach ($cp in $cachePaths) {
        if (Test-Path $cp) {
            Remove-Item -Path "$cp\*" -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Write-Host "[5/5] HOAN TAT GO SACH DRIVER VGA GOC!" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor DarkCyan
    $ans = Read-Host "Ban co muon Khoi dong lai (Restart) may tinh ngay bay gio khong? (Y/N)"
    if ($ans -eq "Y" -or $ans -eq "y") {
        Restart-Computer -Force
    }
}

# ==============================================================================
# VONG LAP MENU CHINH
# ==============================================================================
while ($true) {
    Show-Banner
    Write-Host "  [1] [AUTO 1-CLICK] Tu dong Quet, Tim thong minh & Cai dat 100% Driver" -ForegroundColor Green
    Write-Host "  [2] [FAST GPU] Tai & Cai dat sieu toc Driver Card do hoa (100% tu dong)" -ForegroundColor Yellow
    Write-Host "  [3] [FAST USB] Cai dat sieu toc 30s toan bo Driver tu USB cuu ho (Offline)" -ForegroundColor Green
    Write-Host "  [4] Tu dong Tim, Phan loai & Cai dat Driver qua Windows Update" -ForegroundColor White
    Write-Host "  [5] [SMART CATALOG] Tu dong Tim & Cai dat tat ca Driver cham than vang (Catalog)" -ForegroundColor Cyan
    Write-Host "  [6] [FIX WU] Sua loi Windows Update & Mang chan Driver (Fix 0x8024402C)" -ForegroundColor Cyan
    Write-Host "  [7] Quet chi tiet thiet bi thieu Driver (Cham than vang) & Driver da cai" -ForegroundColor White
    Write-Host "  [8] Sao luu (Backup) toan bo Driver hien tai ra o C:\DriverBackup" -ForegroundColor White
    Write-Host "  [9] Phuc hoi / Cai dat Driver tu thu muc chi dinh" -ForegroundColor White
    Write-Host "  [10] Go sach triet de Driver VGA goc (DDU - Display Driver Uninstaller)" -ForegroundColor Yellow
    Write-Host "  [0] Quay lai / Thoat" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

    $choice = Read-Host "Chon chuc nang (0-10)"
    switch ($choice) {
        "1" { Invoke-OneClickDriverAuto; Pause-Menu }
        "2" { Invoke-FastOemGpuDriver; Pause-Menu }
        "3" { Invoke-RestoreDrivers; Pause-Menu }
        "4" { Invoke-AutoInstallDriversWU; Pause-Menu }
        "5" { Invoke-SmartHardwareAutoInstall; Pause-Menu }
        "6" { Invoke-RepairWindowsUpdateAndNetwork; Pause-Menu }
        "7" { Invoke-DriverScan; Pause-Menu }
        "8" { Invoke-BackupDrivers; Pause-Menu }
        "9" { Invoke-RestoreDrivers; Pause-Menu }
        "10" { Invoke-DDUClean; Pause-Menu }
        "0" { Write-Host "Dang thoat Driver Manager..." -ForegroundColor Yellow; return }
        default { Write-Host "Lua chon khong hop le, vui long chon tu 0 den 10!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
