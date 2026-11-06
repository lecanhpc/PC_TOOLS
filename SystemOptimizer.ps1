<#
.SYNOPSIS
    System Optimizer Pro v2.1 - Cong cu Don dep, Toi uu & Sua loi Windows chuyen sau
.DESCRIPTION
    100% Clean Console Font - Khong loi font tren moi phien ban Windows Console
#>
param(
    [switch]$AutoRun,
    [switch]$OptimizeXeon
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Dang khoi dong lai voi quyen Administrator..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($AutoRun) { $argList += " -AutoRun" }
    if ($OptimizeXeon) { $argList += " -OptimizeXeon" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    return
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
$LogFile = Join-Path -Path $LogDir -ChildPath "SystemOptimizer_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

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
    Write-Host "|          CONG CU DON DEP - TOI UU - SUA LOI WINDOWS (PRO v2.1)         |" -ForegroundColor Yellow
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $volC = Get-Volume -DriveLetter C -ErrorAction SilentlyContinue
    $freeGB = if ($volC) { [math]::Round($volC.SizeRemaining / 1GB, 2) } else { 0 }
    $totalGB = if ($volC) { [math]::Round($volC.Size / 1GB, 2) } else { 0 }
    Write-Host "  He dieu hanh : $($os.Caption) ($($os.OSArchitecture))" -ForegroundColor Gray
    Write-Host "  O dia C:     : Con trong $freeGB GB / $totalGB GB" -ForegroundColor Green
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
}

# ==============================================================================
# 1. DON DEP HE THONG CHUYEN SAU (DEEP CLEANUP)
# ==============================================================================
function Invoke-DeepCleanup {
    param([switch]$Silent)
    Write-Host "`n=== [1] DON DEP RAC HE THONG CHUYEN SAU ===" -ForegroundColor Yellow
    if (-not $Silent) {
        Write-Host "Qua trinh nay se xoa: Temp he thong, Cache Windows Update cu, Prefetch," -ForegroundColor Gray
        Write-Host "Cache trinh duyet (khong mat mat khau/lich su), Crash Dump, Log cu & Thung rac." -ForegroundColor Gray
        $confirm = Read-Host "Ban co muon bat dau don dep ngay? (Y/N, mac dinh Y)"
        if ($confirm -match '^[Nn]$') { return }
    }

    $volBefore = (Get-Volume -DriveLetter C -ErrorAction SilentlyContinue).SizeRemaining
    Write-Log "[+] Bat dau don dep he thong chuyen sau..." "Cyan"

    $cleanTargets = @(
        @{ Name = "Windows Temp"; Path = "$env:windir\Temp\*" },
        @{ Name = "User Temp"; Path = "$env:TEMP\*" },
        @{ Name = "Windows Prefetch"; Path = "$env:windir\Prefetch\*" },
        @{ Name = "Windows Error Reporting (WER)"; Path = "$env:ProgramData\Microsoft\Windows\WER\ReportQueue\*" },
        @{ Name = "WER Archive"; Path = "$env:ProgramData\Microsoft\Windows\WER\ReportArchive\*" },
        @{ Name = "Memory Minidump"; Path = "$env:windir\Minidump\*" },
        @{ Name = "CBS Logs"; Path = "$env:windir\Logs\CBS\*.log" },
        @{ Name = "Thumbnail Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db" },
        @{ Name = "Chrome Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache\*" },
        @{ Name = "Chrome Code Cache"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Code Cache\*" },
        @{ Name = "Edge Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache\*" },
        @{ Name = "Edge Code Cache"; Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Code Cache\*" },
        @{ Name = "CocCoc Cache"; Path = "$env:LOCALAPPDATA\CocCoc\Browser\User Data\Default\Cache\*" }
    )

    $totalSteps = $cleanTargets.Count + 2
    $step = 0

    foreach ($t in $cleanTargets) {
        $step++
        Write-Progress -Activity "Dang don dep rac he thong" -Status "Dang xoa: $($t.Name)" -PercentComplete (($step / $totalSteps) * 100)
        Write-Host "  -> Dang don: $($t.Name)..." -ForegroundColor Gray
        Remove-Item -Path $t.Path -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Don Windows Update Cache
    $step++
    Write-Progress -Activity "Dang don dep rac he thong" -Status "Dang don Windows Update Cache..." -PercentComplete (($step / $totalSteps) * 100)
    Write-Host "  -> Dang don: Windows Update Download Cache..." -ForegroundColor Gray
    Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
    Start-Service -Name wuauserv -ErrorAction SilentlyContinue

    # Don Thung rac
    $step++
    Write-Progress -Activity "Dang don dep rac he thong" -Status "Dang lam sach Thung rac (Recycle Bin)..." -PercentComplete 100
    Write-Host "  -> Dang lam sach: Recycle Bin..." -ForegroundColor Gray
    Clear-RecycleBin -Force -Confirm:$false -ErrorAction SilentlyContinue
    Write-Progress -Activity "Dang don dep rac he thong" -Completed

    $volAfter = (Get-Volume -DriveLetter C -ErrorAction SilentlyContinue).SizeRemaining
    $freedMB = [math]::Round(($volAfter - $volBefore) / 1MB, 2)
    if ($freedMB -lt 0) { $freedMB = 0 }

    Write-Host ""
    Write-Log "[OK] Da don dep hoan tat! Giai phong duoc: $freedMB MB dung luong o C." "Green"
}

# ==============================================================================
# 2. TOI UU HOA HIEU NANG WINDOWS (PERFORMANCE & TWEAKS)
# ==============================================================================
function Invoke-PerformanceOptimize {
    param([switch]$Silent)
    Write-Host "`n=== [2] TOI UU HOA HIEU NANG WINDOWS ===" -ForegroundColor Yellow

    Write-Log "[+] Dang ap dung cac tinh chinh toi uu hoa hieu nang..." "Cyan"

    # 1. Kich hoat che do nguon High / Ultimate Performance
    Write-Host "  -> Kich hoat Power Plan: High / Ultimate Performance..." -ForegroundColor Gray
    try {
        $null = powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-Host "     [OK] Da chuyen che do nguon sang High Performance." -ForegroundColor Green
    } catch {}

    # 2. Toi uu do tre Menu va phan hoi giao dien
    Write-Host "  -> Giam do tre hien thi Menu (MenuShowDelay = 10ms) & tang toc tat ung dung treo..." -ForegroundColor Gray
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "10" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "WaitToKillAppTimeout" -Value "2000" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "HungAppTimeout" -Value "1000" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "AutoEndTasks" -Value "1" -ErrorAction SilentlyContinue

    # 3. Tat Telemetry & Thu thap du lieu chay ngam cua Microsoft
    Write-Host "  -> Tat dich vu thu thap du lieu ngam (Telemetry / DiagTrack)..." -ForegroundColor Gray
    $telemetryServices = @("DiagTrack", "dmwappushservice", "MapsBroker", "lfsvc")
    foreach ($srv in $telemetryServices) {
        if (Get-Service -Name $srv -ErrorAction SilentlyContinue) {
            Stop-Service -Name $srv -Force -ErrorAction SilentlyContinue
            Set-Service -Name $srv -StartupType Disabled -ErrorAction SilentlyContinue
        }
    }
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # 4. Tat Xbox Game DVR chay ngam (giup tang FPS khi dung VGA/choi game)
    Write-Host "  -> Tat GameDVR chay ngam gay tut FPS..." -ForegroundColor Gray
    New-Item -Path "HKCU:\System\GameConfigStore" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKCU:\System\GameConfigStore" -Name "GameDVR_Enabled" -Value 0 -Type DWord -ErrorAction SilentlyContinue
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" -Name "AllowGameDVR" -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # 5. Toi uu DNS Cache
    Write-Host "  -> Toi uu hoa mang & DNS Cache..." -ForegroundColor Gray
    ipconfig /flushdns | Out-Null

    Write-Log "[OK] Da ap dung thanh cong bo tinh chinh toi uu hoa Windows!" "Green"
}

# ==============================================================================
# 3. QUAN LY UNG DUNG KHOI DONG CUNG WINDOWS (STARTUP MANAGER)
# ==============================================================================
function Invoke-StartupManager {
    Write-Host "`n=== [3] QUAN LY UNG DUNG KHOI DONG (STARTUP APPS) ===" -ForegroundColor Yellow
    $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue | Select-Object Name, Command, Location, User
    if (-not $startupItems) {
        Write-Host "Khong tim thay ung dung khoi dong nao." -ForegroundColor Green
        return
    }

    $idx = 1
    $list = @()
    foreach ($item in $startupItems) {
        $list += [PSCustomObject]@{
            STT      = $idx
            TenApp   = $item.Name
            ViTri    = $item.Location
            LenhChay = $item.Command
        }
        $idx++
    }
    $list | Format-Table -AutoSize

    Write-Host "Meo: Ban co the mo nhanh cua so Startup Apps cua Windows de Bat/Tat truc quan." -ForegroundColor Cyan
    $openTM = Read-Host "Ban co muon mo trang Quan ly Startup cua Windows ngay khong? (Y/N)"
    if ($openTM -match '^[Yy]$') {
        Start-Process "ms-settings:startupapps"
    }
}

# ==============================================================================
# 4. SUA LOI WINDOWS CHUYEN SAU (WINDOWS REPAIR & FIX)
# ==============================================================================
function Invoke-WindowsRepairMenu {
    while ($true) {
        Show-Banner
        Write-Host "=== [REPAIR] MENU SUA LOI WINDOWS CHUYEN SAU ===" -ForegroundColor Yellow
        Write-Host "  [1] Quet & sua file he thong bi hong (SFC /scannow)" -ForegroundColor White
        Write-Host "  [2] Sua chua Windows Image chuyen sau (DISM /RestoreHealth)" -ForegroundColor White
        Write-Host "  [3] Sua loi Windows Update bi ket / bao loi (Reset Update Services)" -ForegroundColor White
        Write-Host "  [4] Sua loi Mang / Mat ket noi / Cham than vang Wi-Fi (Reset Network & DNS)" -ForegroundColor White
        Write-Host "  [5] Sua loi Taskbar / Start Menu / Icon bi do + Reset Microsoft Store" -ForegroundColor White
        Write-Host "  [6] Kiem tra loi o cung truc tuyen (CHKDSK Online Scan)" -ForegroundColor White
        Write-Host "  [7] [AUTO] CHAY TAT CA CAC BUOC SUA LOI TU DONG (Khuyen dung khi Win loi)" -ForegroundColor Green
        Write-Host "  [0] Quay lai Menu truoc" -ForegroundColor Red
        Write-Host ""
        $subChoice = Read-Host "Chon chuc nang sua loi (0-7)"

        switch ($subChoice) {
            "1" {
                Write-Log "[+] Dang chay System File Checker (sfc /scannow)..." "Cyan"
                sfc /scannow
                Pause-Menu
            }
            "2" {
                Write-Log "[+] Dang chay DISM /Online /Cleanup-Image /RestoreHealth..." "Cyan"
                DISM.exe /Online /Cleanup-Image /RestoreHealth
                Pause-Menu
            }
            "3" {
                Write-Log "[+] Dang Reset toan bo dich vu Windows Update..." "Cyan"
                $wuServices = @("wuauserv", "cryptSvc", "bits", "msiserver")
                foreach ($s in $wuServices) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
                Remove-Item "$env:windir\SoftwareDistribution\Download\*" -Recurse -Force -ErrorAction SilentlyContinue
                Remove-Item "$env:windir\System32\catroot2\*" -Recurse -Force -ErrorAction SilentlyContinue
                foreach ($s in $wuServices) { Start-Service -Name $s -ErrorAction SilentlyContinue }
                Write-Log "[OK] Da sua loi va khoi dong lai dich vu Windows Update!" "Green"
                Pause-Menu
            }
            "4" {
                Write-Log "[+] Dang sua loi Mang, Reset Winsock, TCP/IP va Flush DNS..." "Cyan"
                ipconfig /release | Out-Null
                ipconfig /flushdns | Out-Null
                ipconfig /renew | Out-Null
                netsh winsock reset | Out-Null
                netsh int ip reset | Out-Null
                Write-Log "[OK] Da dat lai cau hinh mang thanh cong!" "Green"
                Write-Host "Dang kiem tra ket noi toi Google DNS (8.8.8.8)..." -ForegroundColor Cyan
                Test-Connection -ComputerName 8.8.8.8 -Count 3 | Format-Table -AutoSize
                Pause-Menu
            }
            "5" {
                Write-Log "[+] Dang lam moi Icon Cache, khoi dong lai Windows Explorer va Reset Store..." "Cyan"
                Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
                Start-Process explorer.exe
                Start-Process "wsreset.exe" -NoNewWindow -ErrorAction SilentlyContinue
                Write-Log "[OK] Da lam moi giao dien Windows Explorer va Cache Store!" "Green"
                Pause-Menu
            }
            "6" {
                Write-Log "[+] Dang kiem tra suc khoe va loi he thong tep o C (chkdsk C: /scan)..." "Cyan"
                chkdsk C: /scan
                Pause-Menu
            }
            "7" {
                Write-Log "[+] Bat dau quy trinh sua loi Windows tong hop..." "Yellow"
                Write-Host "`n--- Buoc 1/4: Reset dich vu Windows Update ---" -ForegroundColor Cyan
                $wuServices = @("wuauserv", "cryptSvc", "bits", "msiserver")
                foreach ($s in $wuServices) { Stop-Service -Name $s -Force -ErrorAction SilentlyContinue }
                foreach ($s in $wuServices) { Start-Service -Name $s -ErrorAction SilentlyContinue }

                Write-Host "`n--- Buoc 2/4: Reset cau hinh Mang & DNS ---" -ForegroundColor Cyan
                ipconfig /flushdns | Out-Null
                netsh winsock reset | Out-Null

                Write-Host "`n--- Buoc 3/4: Kiem tra o cung truc tuyen (CHKDSK Scan) ---" -ForegroundColor Cyan
                chkdsk C: /scan

                Write-Host "`n--- Buoc 4/4: Quet va sua file he thong (SFC /scannow) ---" -ForegroundColor Cyan
                sfc /scannow

                Write-Log "[OK] Hoan tat quy trinh sua loi Windows tong hop!" "Green"
                Pause-Menu
            }
            "0" { return }
            default { Write-Host "Lua chon khong hop le!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

# ==============================================================================
# 5. TOI UU DONG MAY TRAM XEON & CAY GIA LAP / DA TAB (XEON MULTI-INSTANCE OPTIMIZER)
# ==============================================================================
function Invoke-XeonFarmOptimization {
    param([switch]$Silent)
    Write-Host "`n+========================================================================+" -ForegroundColor Cyan
    Write-Host "|  TOI UU WINDOWS CHO DONG CPU XEON - CAY GIA LAP (LDPLAYER/NOX) & DA TAB |" -ForegroundColor Yellow
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Log "[*] Bat dau tinh chinh he thong chuyen sau cho Xeon / Multi-Core Farming..." "Yellow"

    # 1. Kiem tra & hien thi thong tin CPU
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        $cores = $cpu.NumberOfCores
        $threads = $cpu.NumberOfLogicalProcessors
        Write-Host "  -> CPU hien tai: $($cpu.Name) ($cores Cores / $threads Threads)" -ForegroundColor Green
    } catch {}

    # 2. Tang Desktop Heap & GDI / USER Handle Quota (Chong man hinh den khi chay >15-20 tab/gia lap)
    Write-Host "  [1/7] Tinh chinh Desktop Heap & Gioi han GDI/USER Handle (Tri dut man hinh den)..." -ForegroundColor Cyan
    try {
        $subSysPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\SubSystems"
        if (Test-Path $subSysPath) {
            $winVal = (Get-ItemProperty -Path $subSysPath -Name "Windows" -ErrorAction SilentlyContinue).Windows
            if ($winVal -and $winVal -match "SharedSection=(\d+),(\d+),(\d+)") {
                $newWinVal = $winVal -replace "SharedSection=\d+,\d+,\d+", "SharedSection=1024,20480,20480"
                Set-ItemProperty -Path $subSysPath -Name "Windows" -Value $newWinVal -Force -ErrorAction SilentlyContinue
                Write-Host "        [OK] SharedSection -> 1024,20480,20480 (Tang Desktop Heap len 20MB)" -ForegroundColor Green
            }
        }
        $winNtPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows"
        Set-ItemProperty -Path $winNtPath -Name "GDIProcessHandleQuota" -Value 65535 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $winNtPath -Name "USERProcessHandleQuota" -Value 65535 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "        [OK] GDI & USER Handle Quota -> 65535 (Mo rong toi da tay nam do hoa/cua so)" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi cap nhat Desktop Heap: $_" -ForegroundColor DarkYellow
    }

    # 3. Mo khoa Truc Tiep Phan Cung VT-x (Tat Hyper-V Hypervisor & VBS de gia lap dat 100% FPS)
    Write-Host "  [2/7] Mo khoa truc tiep VT-x phan cung (Tat Hyper-V Hypervisor launch & VBS)..." -ForegroundColor Cyan
    try {
        Start-Process "bcdedit.exe" -ArgumentList "/set hypervisorlaunchtype off" -NoNewWindow -Wait -ErrorAction SilentlyContinue
        $dgPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
        $hvciPath = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity"
        if (-not (Test-Path $dgPath)) { New-Item -Path $dgPath -Force | Out-Null }
        if (-not (Test-Path $hvciPath)) { New-Item -Path $hvciPath -Force | Out-Null }
        Set-ItemProperty -Path $dgPath -Name "EnableVirtualizationBasedSecurity" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $hvciPath -Name "Enabled" -Value 0 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "        [OK] Da tat Hypervisor & VBS - LDPlayer/Nox chay truc tiep VT-x, chong dung 94%" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi tat Hypervisor: $_" -ForegroundColor DarkYellow
    }

    # 4. Toi uu CPU Scheduling & Unpark All Cores (Win32PrioritySeparation & Core Parking)
    Write-Host "  [3/7] Toi uu lich trinh CPU & Danh thuc 100% Core/Thread (Unpark All Cores)..." -ForegroundColor Cyan
    try {
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 36 -Type DWord -Force -ErrorAction SilentlyContinue
        powercfg -setacvalueindex scheme_current sub_processor 0cc5b647-c1df-4637-891a-dec35c318583 100 2>$null
        powercfg -setactive scheme_current 2>$null
        Write-Host "        [OK] Win32PrioritySeparation = 36 (Can bang thoi gian CPU chay da tab/gia lap)" -ForegroundColor Green
        Write-Host "        [OK] Core Parking = 100% (Khong ngu core, toan bo luong Xeon hoat dong toi da)" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi thiet lap CPU priority: $_" -ForegroundColor DarkYellow
    }

    # 5. Toi uu Socket Mang TCP/IP & Proxy (Chong can kiet cong mang khi chay nhieu proxy/browser tab)
    Write-Host "  [4/7] Toi uu mang TCP/IP & Mo rong Port Socket (Chong nghen mang khi chay nhieu proxy)..." -ForegroundColor Cyan
    try {
        $tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Set-ItemProperty -Path $tcpPath -Name "MaxUserPort" -Value 65534 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpPath -Name "TcpTimedWaitDelay" -Value 30 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpPath -Name "Tcp1323Opts" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $tcpPath -Name "DefaultTTL" -Value 64 -Type DWord -Force -ErrorAction SilentlyContinue
        netsh int tcp set global rss=enabled 2>$null | Out-Null
        netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
        Write-Host "        [OK] MaxUserPort = 65534, TIME_WAIT = 30s (Giai phong port ket noi nhanh gap 4 lan)" -ForegroundColor Green
        Write-Host "        [OK] Da bat RSS (Receive Side Scaling) phan bo goi tin mang deu cac Core Xeon" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi toi uu TCP/IP: $_" -ForegroundColor DarkYellow
    }

    # 6. Toi uu Bo Nho Ao (Virtual Memory / Commit Limit) & Large System Cache
    Write-Host "  [5/7] Toi uu Bo nho Ao & Giu Kernel trong RAM (Disable Paging Executive)..." -ForegroundColor Cyan
    try {
        $memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-ItemProperty -Path $memPath -Name "DisablePagingExecutive" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $memPath -Name "LargeSystemCache" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "        [OK] DisablePagingExecutive = 1 (Giu Kernel & Driver trong RAM, giam truy cap dia)" -ForegroundColor Green
        Write-Host "        [OK] LargeSystemCache = 1 (Tang dung luong bo nho dem he thong)" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi toi uu bo nho dem: $_" -ForegroundColor DarkYellow
    }

    # 7. Giam tai O dia (Disable Last Access Update & SysMain SuperFetch)
    Write-Host "  [6/7] Giam tai O dia khi doc ghi song song hang chuc VM/Profile..." -ForegroundColor Cyan
    try {
        fsutil behavior set disablelastaccess 1 2>$null | Out-Null
        if (Get-Service -Name "SysMain" -ErrorAction SilentlyContinue) {
            Stop-Service -Name "SysMain" -Force -ErrorAction SilentlyContinue
            Set-Service -Name "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "        [OK] Da tat SysMain (SuperFetch) - Tri dut diem loi Full Disk 100%" -ForegroundColor Green
        }
        Write-Host "        [OK] Da tat NTFS Last Access Time (Giam do ghi de len o SSD)" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi giam tai o dia: $_" -ForegroundColor DarkYellow
    }

    # 8. Tinh chinh GPU TDR Delay (Chong vang driver card man hinh khi khoi chay nhieu gia lap)
    Write-Host "  [7/7] Tang thoi gian cho GPU (TDR Delay = 10s - Chong reset / crash driver VGA)..." -ForegroundColor Cyan
    try {
        $gfxPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
        if (-not (Test-Path $gfxPath)) { New-Item -Path $gfxPath -Force | Out-Null }
        Set-ItemProperty -Path $gfxPath -Name "TdrDelay" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Set-ItemProperty -Path $gfxPath -Name "TdrDdiDelay" -Value 10 -Type DWord -Force -ErrorAction SilentlyContinue
        Write-Host "        [OK] TdrDelay & TdrDdiDelay = 10 (Chong vang/crash VGA khi load nhieu tab)" -ForegroundColor Green
    } catch {
        Write-Host "        [!] Loi khi set TdrDelay: $_" -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Log "[OK] HOAN TAT TOI UU MAY TRAM XEON & CAY GIA LAP / DA TAB!" "Green"
    Write-Host "Luu y: Mot so thay doi (SharedSection, Hypervisor, TDR) se co hieu luc toi da sau khi Khoi dong lai Windows!" -ForegroundColor Yellow
}

# ==============================================================================
# CHE DO 1-CLICK TU DONG (AUTO RUN)
# ==============================================================================
function Invoke-OneClickAll {
    Show-Banner
    Write-Host "[AUTO] BAT DAU QUY TRINH TU DONG: DON RAC + TOI UU + SUA LOI NHANH..." -ForegroundColor Green
    Invoke-DeepCleanup -Silent
    Invoke-PerformanceOptimize -Silent
    Write-Host "`n=== [3] SUA LOI NHANH HE THONG & MANG ===" -ForegroundColor Yellow
    Write-Host "  -> Dang Flush DNS & Reset Winsock..." -ForegroundColor Gray
    ipconfig /flushdns | Out-Null
    netsh winsock reset | Out-Null
    Write-Host "  -> Dang kiem tra he thong tep o C (chkdsk /scan)..." -ForegroundColor Gray
    chkdsk C: /scan
    Write-Host ""
    Write-Log "[OK] HOAN TAT TOAN BO QUA TRINH DON DEP & TOI UU WINDOWS!" "Green"
    Write-Host "File nhat ky duoc luu tai: $LogFile" -ForegroundColor DarkGray
}

if ($AutoRun) {
    Invoke-OneClickAll
    return
}

if ($OptimizeXeon) {
    Invoke-XeonFarmOptimization
    Pause-Menu
    return
}

# ==============================================================================
# VONG LAP MENU CHINH
# ==============================================================================
while ($true) {
    Show-Banner
    Write-Host "  [1] [AUTO] TU DONG TOI UU TOAN DIEN (1-Click: Don rac + Toi uu + Sua loi nhanh)" -ForegroundColor Green
    Write-Host "  [2] Don dep rac he thong chuyen sau (Temp, Update, Cache, Recycle Bin)" -ForegroundColor White
    Write-Host "  [3] Toi uu hieu nang Windows (Power Plan, Tat Telemetry/Lag, Tang toc UI)" -ForegroundColor White
    Write-Host "  [4] Sua loi Windows chuyen sau (SFC, DISM, Sua loi Update, Mang, Store)" -ForegroundColor White
    Write-Host "  [5] Quan ly ung dung khoi dong cung Windows (Startup Apps)" -ForegroundColor White
    Write-Host "  [6] Toi uu may tram Xeon & CPU nhieu core (Cay gia lap LDPlayer/Nox & mo hang tram tab Web)" -ForegroundColor Yellow
    Write-Host "  [0] Quay lai / Thoat" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

    $choice = Read-Host "Chon chuc nang (0-6)"
    switch ($choice) {
        "1" { Invoke-OneClickAll; Pause-Menu }
        "2" { Invoke-DeepCleanup; Pause-Menu }
        "3" { Invoke-PerformanceOptimize; Pause-Menu }
        "4" { Invoke-WindowsRepairMenu }
        "5" { Invoke-StartupManager; Pause-Menu }
        "6" { Invoke-XeonFarmOptimization; Pause-Menu }
        "0" { Write-Host "Dang thoat System Optimizer..." -ForegroundColor Yellow; return }
        default { Write-Host "Lua chon khong hop le, vui long chon tu 0 den 6!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
