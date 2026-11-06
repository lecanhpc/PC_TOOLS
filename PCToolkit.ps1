<#
.SYNOPSIS
    PC Optimization Toolkit v2.2 - Main Launcher
.DESCRIPTION
    Bo cong cu Toi uu, Chong Do Giat, Sua loi Windows & Quan ly Driver Tu dong (100% Clean Font)
#>

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Dang khoi dong lai Bo Cong Cu voi quyen Administrator..."
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$Host.UI.RawUI.WindowTitle = "BO CONG CU TOI UU MAY TINH & DRIVER PRO v2.2"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Kiem tra ban quyen LC_SOFT (Bao ve chong dung chua kich hoat)
$secFile = Join-Path -Path $ScriptDir -ChildPath "ToolkitSecurity.ps1"
if (Test-Path $secFile) { . $secFile }
$licRes = Test-ToolkitLicense -BaseDir $ScriptDir
if (-not $licRes -or -not $licRes.IsValid) {
    Clear-Host
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "  [!] PHAN MEM YEU CAU BAN QUYEN HOAC KEY DUNG THU 7 NGAY TU LC_SOFT!    " -ForegroundColor Yellow
    Write-Host "==========================================================================" -ForegroundColor Red
    $hw = Get-HardwareID -Path $ScriptDir
    Write-Host "  Ma thiet bi phan cung cua ban (HWID): $($hw.HWID)" -ForegroundColor Cyan
    Write-Host "  Trang thai: $($licRes.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "  -> Vui long gui ma HWID tren qua Zalo: 0979.298.897 (Le Canh PC)" -ForegroundColor White
    Write-Host "     de nhan file license.lic kich hoat Dung Thu 7 Ngay hoac Vinh Vien!" -ForegroundColor White
    Write-Host "==========================================================================" -ForegroundColor Red
    Write-Host "Nhan phim bat ky de thoat..." -ForegroundColor Gray
    try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") } catch {}
    exit
}

function Show-Banner {
    Clear-Host
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Host "|              BO CONG CU TOI UU MAY TINH & DRIVER PRO v2.2              |" -ForegroundColor Yellow
    Write-Host "|                     PC OPTIMIZATION TOOLKIT PRO                        |" -ForegroundColor Green
    Write-Host "+========================================================================+" -ForegroundColor Cyan
}

function Show-SystemSummary {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
    $totalRam = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $gpu = (Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name) -join " | "
    $missingDrv = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'OK' -and $_.ConfigManagerErrorCode -ne 'CM_PROB_DISABLED' }).Count

    Write-Host "  May tinh       : $($cs.Name) ($($cs.Manufacturer) $($cs.Model))" -ForegroundColor White
    Write-Host "  He dieu hanh   : $($os.Caption)" -ForegroundColor White
    Write-Host "  Cau hinh       : $($cpu.Name) | RAM: Trong $freeRam GB / $totalRam GB" -ForegroundColor White
    Write-Host "  Card do hoa    : $gpu" -ForegroundColor White
    if ($missingDrv -gt 0) {
        Write-Host "  Trang thai Drv : [!] Phat hien $missingDrv thiet bi dang thieu/loi Driver!" -ForegroundColor Red
    } else {
        Write-Host "  Trang thai Drv : [OK] Tat ca thiet bi phan cung da nhan dien tot" -ForegroundColor Green
    }
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Invoke-SubScript {
    param([string]$ScriptName, [switch]$AutoRun)
    $path = Join-Path -Path $ScriptDir -ChildPath $ScriptName
    if (Test-Path $path) {
        if ($AutoRun) {
            & $path -AutoRun
        } else {
            & $path
        }
    } else {
        Write-Warning "Khong tim thay file $ScriptName tai $ScriptDir"
        Read-Host "Nhan Enter de tiep tuc" | Out-Null
    }
}

while ($true) {
    Show-Banner
    Show-SystemSummary

    Write-Host "  [1] CHONG DO GIAT & XA RAM STANDBY TUC THI (Anti-Lag & Stutter Fixer)" -ForegroundColor Yellow
    Write-Host "      - Tri may chay nang xong bi do/giat, xa 5-10GB RAM dem, diet app treo" -ForegroundColor Gray
    Write-Host "  [2] DON DEP, TOI UU & SUA LOI WINDOWS (System Optimizer Pro)" -ForegroundColor Green
    Write-Host "      - Don rac chuyen sau, tang toc Win, sua loi SFC/DISM/Update/Mang" -ForegroundColor Gray
    Write-Host "  [3] QUET, CAI DAT & BACKUP DRIVER TU DONG (Driver Manager Pro)" -ForegroundColor Green
    Write-Host "      - Quet thiet bi cham than vang, tu dong tai & cai Driver, Backup/Restore" -ForegroundColor Gray
    Write-Host "  [4] CHE DO TU DONG TOAN DIEN (1-Click: Chong Giat + Don Rac + Cai Driver)" -ForegroundColor Cyan
    Write-Host "      - Tu dong chay toan bo cho may vua cai lai Win hoac may dang cham/loi" -ForegroundColor Gray
    Write-Host "  [5] KIEM TRA PHAN CUNG & XUAT BAO CAO (VGA, RAM, CPU, O cung, Pin)" -ForegroundColor White
    Write-Host "  [6] TOI UU MAY TRAM XEON & CPU NHIEU CORE (Cay Gia Lap & Da Tab Web)" -ForegroundColor Magenta
    Write-Host "      - Tri man hinh den, tat Hypervisor mo VT-x 100% FPS, unpark core, mo 65k port" -ForegroundColor Gray
    Write-Host "  [0] Thoat chuong trinh" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

    $choice = Read-Host "Nhap lua chon cua ban (0-6)"
    switch ($choice) {
        "1" { Invoke-SubScript -ScriptName "AntiLagBooster.ps1" }
        "2" { Invoke-SubScript -ScriptName "SystemOptimizer.ps1" }
        "3" { Invoke-SubScript -ScriptName "DriverManager.ps1" }
        "4" {
            Clear-Host
            Write-Host "[AUTO] DANG CHAY CHE DO TU DONG TOAN DIEN (CHONG GIAT + DRIVER + DON RAC)..." -ForegroundColor Yellow
            Invoke-SubScript -ScriptName "AntiLagBooster.ps1" -AutoRun
            Invoke-SubScript -ScriptName "DriverManager.ps1" -AutoRun
            Invoke-SubScript -ScriptName "SystemOptimizer.ps1" -AutoRun
            Invoke-SubScript -ScriptName "HardwareDiagnostics.ps1" -AutoRun
            Write-Host "`n[OK] DA HOAN TAT TOAN BO QUY TRINH TU DONG!" -ForegroundColor Green
            Read-Host "Nhan phim Enter de quay lai Menu chinh" | Out-Null
        }
        "5" { Invoke-SubScript -ScriptName "HardwareDiagnostics.ps1" }
        "6" {
            $p = Join-Path -Path $ScriptDir -ChildPath "SystemOptimizer.ps1"
            if (Test-Path $p) { & $p -OptimizeXeon }
        }
        "0" { Write-Host "Tam biet!"; exit }
        default { Write-Host "Lua chon khong hop le!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
