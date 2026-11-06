<#
.SYNOPSIS
    Cong cu Kiem tra Phan cung PC (PC Hardware Diagnostics v2.1)
.DESCRIPTION
    100% Clean Console Font + Xuat bao cao HTML chuyen nghiep
#>
param(
    [switch]$AutoRun
)

$ErrorActionPreference = 'SilentlyContinue'

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

function Show-Banner {
    Clear-Host
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Host "|            CONG CU KIEM TRA PHAN CUNG TOAN DIEN (PRO v2.1)             |" -ForegroundColor Yellow
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Show-Menu {
    Write-Host "  [1] Kiem tra Card do hoa (GPU / VGA)" -ForegroundColor White
    Write-Host "  [2] Kiem tra Bo nho RAM (Dung luong, Toc do, Khe cam)" -ForegroundColor White
    Write-Host "  [3] Kiem tra He thong chung (CPU, O cung SMART, Mainboard, BIOS, Pin)" -ForegroundColor White
    Write-Host "  [4] [AUTO] Chay toan bo kiem tra va Xuat Bao Cao HTML" -ForegroundColor Green
    Write-Host "  [0] Quay lai / Thoat" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Get-HealthScore ($ramUsage, $diskHealth, $batteryHealth) {
    $score = 100
    if ($ramUsage -gt 90) { $score -= 20 }
    elseif ($ramUsage -gt 75) { $score -= 10 }
    if ($diskHealth -eq 'Warning') { $score -= 30 }
    elseif ($diskHealth -eq 'Error') { $score -= 50 }
    if ($null -ne $batteryHealth -and $batteryHealth -lt 50) { $score -= 20 }
    elseif ($null -ne $batteryHealth -and $batteryHealth -lt 80) { $score -= 10 }
    if ($score -lt 0) { $score = 0 }
    return $score
}

function Get-GPUInfo {
    Write-Host "`n--- [1] KIEM TRA GPU / VGA ---" -ForegroundColor Cyan
    $gpus = Get-CimInstance Win32_VideoController
    $gpuData = @()
    foreach ($gpu in $gpus) {
        $vram = if ($gpu.AdapterRAM) { [math]::Round($gpu.AdapterRAM / 1GB, 2) } else { 0 }
        Write-Host "  Ten GPU          : $($gpu.Name)" -ForegroundColor Green
        Write-Host "  Phien ban Driver : $($gpu.DriverVersion)"
        Write-Host "  Ngay Driver      : $($gpu.DriverDate)"
        Write-Host "  Dung luong VRAM  : $vram GB"
        $gpuData += [PSCustomObject]@{
            Name          = $gpu.Name
            DriverVersion = $gpu.DriverVersion
            VRAM          = "$vram GB"
        }
    }
    Write-Host ""
    return $gpuData
}

function Get-RAMInfo {
    Write-Host "`n--- [2] KIEM TRA BO NHO RAM ---" -ForegroundColor Cyan
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $physMem = @(Get-CimInstance Win32_PhysicalMemory)

    $totalRam = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    $freeRam = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedRam = [math]::Round($totalRam - $freeRam, 2)
    $ramUsage = [math]::Round(($usedRam / $totalRam) * 100, 2)

    Write-Host "  Tong dung luong RAM : $totalRam GB"
    Write-Host "  RAM dang trong      : $freeRam GB"
    $color = if ($ramUsage -gt 85) { "Red" } elseif ($ramUsage -gt 70) { "Yellow" } else { "Green" }
    Write-Host "  Muc su dung RAM     : $ramUsage % ($usedRam GB)" -ForegroundColor $color
    Write-Host "  So thanh RAM da cam : $($physMem.Count) thanh"

    $ramSticks = @()
    $idx = 1
    foreach ($stick in $physMem) {
        $cap = [math]::Round($stick.Capacity / 1GB, 2)
        $speed = $stick.Speed
        $manu = if ($stick.Manufacturer) { $stick.Manufacturer.Trim() } else { "OEM" }
        $loc = if ($stick.DeviceLocator) { $stick.DeviceLocator.Trim() } else { "Khe $idx" }
        $part = if ($stick.PartNumber) { $stick.PartNumber.Trim() } else { "N/A" }
        $sn = if ($stick.SerialNumber) { $stick.SerialNumber.Trim() } else { "N/A" }
        Write-Host "    -> [Thanh $idx] Khe: $loc | Hang: $manu | $cap GB | $speed MHz" -ForegroundColor Green
        Write-Host "       Part: $part | Serial: $sn" -ForegroundColor Gray
        $ramSticks += [PSCustomObject]@{ Slot = $loc; Manufacturer = $manu; Capacity = "$cap GB"; Speed = "$speed MHz"; PartNumber = $part; Serial = $sn }
        $idx++
    }

    # Quet nhanh loi WHEA Memory
    try {
        $whea = @(Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WHEA-Logger'} -MaxEvents 20 -ErrorAction SilentlyContinue)
        $ramWhea = @($whea | Where-Object { $_.Message -match "Memory|ECC|Parity|DIMM" })
        if ($ramWhea.Count -gt 0) {
            Write-Host "  [CANH BAO] Phat hien $($ramWhea.Count) su kien WHEA loi phan cung RAM!" -ForegroundColor Red
        } else {
            Write-Host "  [OK] Nhat ky phan cung WHEA: 0 loi Memory Parity/ECC." -ForegroundColor Green
        }
    } catch {}

    Write-Host ""
    return @{ Total = $totalRam; Free = $freeRam; Usage = $ramUsage; Details = $ramSticks }
}

function Get-GeneralInfo {
    Write-Host "`n--- [3] KIEM TRA HE THONG CHUNG ---" -ForegroundColor Cyan
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    Write-Host "  CPU               : $($cpu.Name)" -ForegroundColor Green
    Write-Host "  So nhan / Luong   : $($cpu.NumberOfCores) Nhan / $($cpu.NumberOfLogicalProcessors) Luong"

    $disks = Get-CimInstance MSFT_PhysicalDisk -Namespace Root\Microsoft\Windows\Storage
    $diskInfo = @()
    if ($disks) {
        foreach ($d in $disks) {
            $health = $d.HealthStatus
            $size = [math]::Round($d.Size / 1GB, 2)
            $color = if ($health -eq 'Healthy') { 'Green' } else { 'Red' }
            Write-Host "  O cung            : $($d.FriendlyName) - $size GB - Suc khoe: $health" -ForegroundColor $color
            $diskInfo += [PSCustomObject]@{ Name = $d.FriendlyName; Size = "$size GB"; Health = $health }
        }
    } else {
        $logicalDisks = Get-CimInstance Win32_DiskDrive
        foreach ($d in $logicalDisks) {
            $size = [math]::Round($d.Size / 1GB, 2)
            Write-Host "  O cung            : $($d.Model) - $size GB - Trang thai: $($d.Status)"
            $diskInfo += [PSCustomObject]@{ Name = $d.Model; Size = "$size GB"; Health = $d.Status }
        }
    }

    $mb = Get-CimInstance Win32_BaseBoard
    Write-Host "  Bo mach chu       : $($mb.Manufacturer) - $($mb.Product)"
    $bios = Get-CimInstance Win32_BIOS
    Write-Host "  Phien ban BIOS    : $($bios.SMBIOSBIOSVersion)"

    $battery = Get-CimInstance Win32_Battery
    $batteryHealth = $null
    if ($battery) {
        $designCap = $battery.DesignCapacity
        $fullCap = $battery.FullChargeCapacity
        if ($designCap -and $fullCap) {
            $batteryHealth = [math]::Round(($fullCap / $designCap) * 100, 2)
            Write-Host "  Suc khoe Pin      : $batteryHealth %" -ForegroundColor Yellow
        } else {
            Write-Host "  Trang thai Pin    : Dang su dung (Laptop)"
        }
    } else {
        Write-Host "  Pin               : Khong co (May ban PC)"
    }

    $usbs = @(Get-CimInstance Win32_USBControllerDevice).Count
    Write-Host "  Thiet bi USB      : $usbs thiet bi dang ket noi"
    Write-Host ""
    return @{ CPU = $cpu; Disks = $diskInfo; MB = $mb; BIOS = $bios; BatteryHealth = $batteryHealth; USBCount = $usbs }
}

function Generate-HtmlReport ($gpu, $ram, $general, $score) {
    $reportPath = Join-Path -Path $PSScriptRoot -ChildPath "BaoCao_PhanCung_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $html = @"
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <title>Bao cao Kiem tra Phan cung PC</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, sans-serif; background-color: #f4f7f6; color: #333; margin: 0; padding: 20px; }
        .container { max-width: 900px; margin: 0 auto; background: #fff; padding: 30px; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        h1, h2 { color: #2c3e50; border-bottom: 2px solid #3498db; padding-bottom: 10px; }
        h1 { text-align: center; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #3498db; color: white; }
        .score-box { text-align: center; margin: 25px 0; padding: 20px; background-color: #ecf0f1; border-radius: 8px; }
        .score { font-size: 48px; font-weight: bold; color: #27ae60; }
    </style>
</head>
<body>
    <div class="container">
        <h1>BAO CAO KIEM TRA PHAN CUNG MAY TINH</h1>
        <div class="score-box">
            <h3>Diem Suc Khoe He Thong</h3>
            <div class="score">$score / 100</div>
        </div>
        <h2>1. Thong tin CPU & He thong</h2>
        <table>
            <tr><th>Thanh phan</th><th>Thong tin</th></tr>
            <tr><td>Ten CPU</td><td>$($general.CPU.Name)</td></tr>
            <tr><td>So nhan / Luong</td><td>$($general.CPU.NumberOfCores) Nhan / $($general.CPU.NumberOfLogicalProcessors) Luong</td></tr>
            <tr><td>Bo mach chu (Mainboard)</td><td>$($general.MB.Manufacturer) $($general.MB.Product)</td></tr>
            <tr><td>Phien ban BIOS</td><td>$($general.BIOS.SMBIOSBIOSVersion)</td></tr>
            <tr><td>Thiet bi USB ket noi</td><td>$($general.USBCount)</td></tr>
        </table>
        <h2>2. Bo nho (RAM)</h2>
        <p><strong>Tong RAM:</strong> $($ram.Total) GB | <strong>Da dung:</strong> $($ram.Usage)%</p>
        <table>
            <tr><th>Nha san xuat</th><th>Dung luong</th><th>Toc do</th></tr>
            $(($ram.Details | ForEach-Object { "<tr><td>$($_.Manufacturer)</td><td>$($_.Capacity)</td><td>$($_.Speed)</td></tr>" }) -join '')
        </table>
        <h2>3. Do hoa (GPU)</h2>
        <table>
            <tr><th>Ten GPU</th><th>Phien ban Driver</th><th>VRAM</th></tr>
            $(($gpu | ForEach-Object { "<tr><td>$($_.Name)</td><td>$($_.DriverVersion)</td><td>$($_.VRAM)</td></tr>" }) -join '')
        </table>
        <h2>4. O dia (Luu tru)</h2>
        <table>
            <tr><th>Ten o cung</th><th>Dung luong</th><th>Trang thai suc khoe</th></tr>
            $(($general.Disks | ForEach-Object { "<tr><td>$($_.Name)</td><td>$($_.Size)</td><td>$($_.Health)</td></tr>" }) -join '')
        </table>
    </div>
</body>
</html>
"@
    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "[OK] Da xuat bao cao HTML thanh cong tai: $reportPath" -ForegroundColor Green
}

if ($AutoRun) {
    Write-Host "`n=== [DIAGNOSTICS] DANG KIEM TRA PHAN CUNG & XUAT BAO CAO HTML ===" -ForegroundColor Yellow
    $gpu = Get-GPUInfo
    $ram = Get-RAMInfo
    $gen = Get-GeneralInfo
    $worstDisk = 'Healthy'
    if ($gen.Disks.Health -contains 'Error' -or $gen.Disks.Health -contains 'Pred Fail') { $worstDisk = 'Error' }
    elseif ($gen.Disks.Health -contains 'Warning') { $worstDisk = 'Warning' }
    $score = Get-HealthScore -ramUsage $ram.Usage -diskHealth $worstDisk -batteryHealth $gen.BatteryHealth
    Generate-HtmlReport -gpu $gpu -ram $ram -general $gen -score $score
    return
}

while ($true) {
    Show-Banner
    Show-Menu
    $choice = Read-Host "Nhap lua chon cua ban (0-4)"
    switch ($choice) {
        '1' { Get-GPUInfo | Out-Null; Read-Host "Nhan Enter de tiep tuc" | Out-Null }
        '2' { Get-RAMInfo | Out-Null; Read-Host "Nhan Enter de tiep tuc" | Out-Null }
        '3' { Get-GeneralInfo | Out-Null; Read-Host "Nhan Enter de tiep tuc" | Out-Null }
        '4' {
            $gpu = Get-GPUInfo
            $ram = Get-RAMInfo
            $gen = Get-GeneralInfo
            $worstDisk = 'Healthy'
            if ($gen.Disks.Health -contains 'Error' -or $gen.Disks.Health -contains 'Pred Fail') { $worstDisk = 'Error' }
            elseif ($gen.Disks.Health -contains 'Warning') { $worstDisk = 'Warning' }
            $score = Get-HealthScore -ramUsage $ram.Usage -diskHealth $worstDisk -batteryHealth $gen.BatteryHealth
            Generate-HtmlReport -gpu $gpu -ram $ram -general $gen -score $score
            Read-Host "Nhan Enter de tiep tuc" | Out-Null
        }
        '0' { return }
        default { Write-Host "Lua chon khong hop le!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
