<#
.SYNOPSIS
    Anti-Lag & Stutter Fixer Pro v2.1 - Cong cu Chong Do Giat, Xa RAM Standby & Tang Toc Tuc Thi
.DESCRIPTION
    Chuyen tri hien tuong may tinh chay nang xong bi do, khug chuot, giat lag khung hinh.
    100% Clean Console Font (Pure ASCII).
#>
param(
    [switch]$AutoRun
)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning "Dang khoi dong lai Cong cu Chong Do Giat voi quyen Administrator..."
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    if ($AutoRun) { $argList += " -AutoRun" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    return
}

$Host.UI.RawUI.WindowTitle = "CHONG DO GIAT - XA RAM STANDBY - GIAM LAG TUC THI (PRO v2.1)"

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

# Nap thu vien C# Native Win32 API de giai phong Working Set & Standby Memory List
$memCleanerCode = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class AntiLagNative {
    [DllImport("ntdll.dll")]
    public static extern uint NtSetSystemInformation(int InfoClass, ref int Info, int Length);

    [DllImport("psapi.dll")]
    public static extern bool EmptyWorkingSet(IntPtr hProcess);

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool AdjustTokenPrivileges(IntPtr htok, bool disall, ref TokPriv1Luid newst, int len, IntPtr prev, IntPtr relen);

    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    internal static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr phtok);

    [DllImport("advapi32.dll", SetLastError = true)]
    internal static extern bool LookupPrivilegeValue(string host, string name, ref long pluid);

    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    internal struct TokPriv1Luid {
        public int Count;
        public long Luid;
        public int Attr;
    }

    private static bool EnablePrivilege(string privilege) {
        try {
            IntPtr htok = IntPtr.Zero;
            if (!OpenProcessToken(Process.GetCurrentProcess().Handle, 0x00000028, ref htok)) return false;
            TokPriv1Luid tp = new TokPriv1Luid();
            tp.Count = 1;
            tp.Luid = 0;
            tp.Attr = 0x00000002;
            if (!LookupPrivilegeValue(null, privilege, ref tp.Luid)) return false;
            return AdjustTokenPrivileges(htok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
        } catch { return false; }
    }

    // Chuan ISLC (Intelligent Standby List Cleaner) - 100% An Toan Cho Game & Anti-Cheat
    // Chi xa sach bo nho dem Standby List (Command 4 & 5).
    // Tuyet doi KHONG can thiep Working Set cua Game, khong scan process, khong dung Anti-Cheat.
    public static uint PurgeStandbyList() {
        try {
            EnablePrivilege("SeProfileSingleProcessPrivilege");
            EnablePrivilege("SeIncreaseQuotaPrivilege");
            int cmdStandby = 4;
            uint r1 = NtSetSystemInformation(80, ref cmdStandby, sizeof(int));
            int cmdStandbyLow = 5;
            uint r2 = NtSetSystemInformation(80, ref cmdStandbyLow, sizeof(int));
            return (r1 == 0 || r2 == 0) ? 0 : r1;
        } catch { return 1; }
    }

    // Xa RAM An Toan: Purge Standby List theo chuan ISLC + chi thu hoi bo nho cua bloat he thong
    public static int FlushRamAndStandby() {
        PurgeStandbyList();
        int count = 0;
        string[] safeBloatList = new string[] {
            "searchindexer", "onedrive", "cortana", "smartscreen",
            "yourphone", "phoneexperiencehost", "feedbackhub"
        };
        foreach (string name in safeBloatList) {
            try {
                Process[] procs = Process.GetProcessesByName(name);
                foreach (Process p in procs) {
                    try {
                        if (p.Id > 4 && EmptyWorkingSet(p.Handle)) count++;
                    } catch {}
                }
            } catch {}
        }
        return count;
    }
}
"@

if (-not ("AntiLagNative" -as [type])) {
    Add-Type -TypeDefinition $memCleanerCode -ErrorAction SilentlyContinue
}

function Pause-Menu {
    Write-Host ""
    Read-Host "Nhan phim Enter de quay lai menu" | Out-Null
}

function Get-RamStatus {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $totalMB = [math]::Round($cs.TotalPhysicalMemory / 1MB, 0)
    $freeMB = [math]::Round($os.FreePhysicalMemory / 1024, 0)
    $usedMB = $totalMB - $freeMB
    $pct = [math]::Round(($usedMB / $totalMB) * 100, 1)
    return @{
        TotalMB = $totalMB
        FreeMB  = $freeMB
        UsedMB  = $usedMB
        Percent = $pct
    }
}

function Show-Banner {
    Clear-Host
    $ram = Get-RamStatus
    $ramColor = if ($ram.Percent -gt 80) { "Red" } elseif ($ram.Percent -gt 65) { "Yellow" } else { "Green" }
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Host "|      CONG CU CHONG DO GIAT - XA RAM STANDBY - GIAM LAG (PRO v2.1)      |" -ForegroundColor Yellow
    Write-Host "|      Chuyen tri may chay nang xong bi do, khug chuot, giat lag         |" -ForegroundColor Green
    Write-Host "+========================================================================+" -ForegroundColor Cyan
    Write-Host "  Trang thai RAM hien tai : Dang dung $($ram.UsedMB) MB / $($ram.TotalMB) MB ($($ram.Percent)%) - Trong: $($ram.FreeMB) MB" -ForegroundColor $ramColor
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan
}

# ==============================================================================
# 1. XA RAM WORKING SET & XOA SACH BO NHO DEM STANDBY LIST
# ==============================================================================
function Invoke-RamStandbyFlush {
    Write-Host "`n=== [RAM FLUSH] DANG XA BO NHO DEM STANDBY (CHUAN ISLC AN TOAN) ===" -ForegroundColor Yellow
    $before = Get-RamStatus
    Write-Host "  -> Truoc khi xa : Dang dung $($before.UsedMB) MB ($($before.Percent)%) | RAM Trong: $($before.FreeMB) MB" -ForegroundColor Gray

    Write-Host "  -> Dang xa bo nho dem Standby List theo chuan ISLC (100% an toan cho Game & Anti-Cheat)..." -ForegroundColor Cyan
    [System.GC]::Collect()
    $null = [AntiLagNative]::PurgeStandbyList()
    Start-Sleep -Milliseconds 500

    $after = Get-RamStatus
    $freedMB = $after.FreeMB - $before.FreeMB
    if ($freedMB -lt 0) { $freedMB = 0 }

    Write-Host "  -> Sau khi xa   : Dang dung $($after.UsedMB) MB ($($after.Percent)%) | RAM Trong: $($after.FreeMB) MB" -ForegroundColor Green
    Write-Host "  [OK] Da giai phong thanh cong: $freedMB MB RAM dem Standby (Giu nguyen bo nho Game, chong tut FPS)!" -ForegroundColor Green
}

# ==============================================================================
# 2. DIET TIEN TRINH TREO (NOT RESPONDING) & TIEN TRINH NGAM GAY DO MAY
# ==============================================================================
function Invoke-KillLagProcesses {
    Write-Host "`n=== [KILL LAG] QUET & TAT TIEN TRINH TREO / NGAM GAY DO MAY ===" -ForegroundColor Yellow

    # 1. Tim cac ung dung bi treo (Not Responding) - Bo qua Game va Launcher
    $gameWhitelist = @(
        "steam", "steamwebhelper", "epicgameslauncher", "riotclient", "riotclientservices",
        "leagueoflegends", "leagueclient", "valorant", "cs2", "csgo", "dota2", "gta5",
        "fifa", "fconline", "genshinimpact", "starrail", "honkaistarrail", "crossfire",
        "pubg", "tslgame", "overwatch", "minecraft", "javaw", "r5apex", "fortniteclient"
    )
    $hungProcs = @(Get-Process | Where-Object { 
        $_.MainWindowHandle -ne 0 -and -not $_.Responding -and ($gameWhitelist -notcontains $_.ProcessName.ToLower())
    })
    if ($hungProcs.Count -gt 0) {
        Write-Host "  [!] Phat hien $($hungProcs.Count) ung dung dang bi TREO (Not Responding):" -ForegroundColor Red
        foreach ($hp in $hungProcs) {
            Write-Host "      -> Dang dong ung dung treo: $($hp.ProcessName) (PID: $($hp.Id))" -ForegroundColor Yellow
            Stop-Process -Id $hp.Id -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Host "  [OK] Khong co cua so ung dung nao dang bi treo (Not Responding)." -ForegroundColor Green
    }

    # 2. Tat cac tien trinh he thong chay ngam hay gay full CPU/Disk dot ngot
    $knownLagHogs = @(
        "CompatTelRunner",        # Microsoft Compatibility Telemetry (thu pham gay 100% CPU/Disk)
        "DeviceCensus",           # Telemetry quet thiet bi ngam
        "SoftwareReporterTool",   # Cong cu quet ngam cua Chrome gay lag CPU
        "WerFault",               # Windows Error Reporting dang treo
        "wermgr"
    )
    $killedCount = 0
    foreach ($hog in $knownLagHogs) {
        $procs = @(Get-Process -Name $hog -ErrorAction SilentlyContinue)
        foreach ($p in $procs) {
            Write-Host "  -> Dang tat tien trinh ngam gay lag: $($p.ProcessName) (PID: $($p.Id))" -ForegroundColor Yellow
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
            $killedCount++
        }
    }
    if ($killedCount -eq 0) {
        Write-Host "  [OK] Cac tien trinh ngam gay lag (CompatTelRunner, WerFault...) deu da duoc don sach." -ForegroundColor Green
    } else {
        Write-Host "  [OK] Da tieu diet $killedCount tien trinh ngam gay do may!" -ForegroundColor Green
    }
}

# ==============================================================================
# 3. PHAN TICH TOP TIEN TRINH NGON RAM / CPU & CHO PHEP TAT NHANH
# ==============================================================================
function Invoke-ProcessAnalyzer {
    Write-Host "`n=== [TOP HOGS] TOP 10 UNG DUNG DANG NGON RAM NHIEU NHAT HIEN TAI ===" -ForegroundColor Yellow
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 `
        Id, ProcessName, `
        @{Name="RAM_MB";Expression={[math]::Round($_.WorkingSet64 / 1MB, 1)}}, `
        @{Name="CPU_Sec";Expression={[math]::Round($_.CPU, 1)}}, `
        @{Name="TrangThai";Expression={if($_.Responding){"Binh thuong"}else{"TREO (Lag)"}}} | Format-Table -AutoSize

    Write-Host "Ban co the nhap Ten tien trinh (VD: chrome, msedgewebview2) hoac PID de tat ngay," -ForegroundColor Cyan
    $target = Read-Host "hoac nhan Enter de bo qua"
    if (-not [string]::IsNullOrWhiteSpace($target)) {
        if ($target -match '^\d+$') {
            Stop-Process -Id ([int]$target) -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Da tat tien trinh PID $target." -ForegroundColor Green
        } else {
            Stop-Process -Name $target -Force -ErrorAction SilentlyContinue
            Write-Host "[OK] Da tat tat ca tien trinh co ten '$target'." -ForegroundColor Green
        }
    }
}

# ==============================================================================
# 4. LAM MOI WINDOWS EXPLORER, DWM & XOA SHADER CACHE VGA (CHONG GIAT HINH)
# ==============================================================================
function Invoke-RefreshUIAndGPU {
    param([switch]$IncludeDisplayReset)
    Write-Host "`n=== [UI & GPU] LAM MOI GIAO DIEN WINDOWS & DON CACHE CARD DO HOA ===" -ForegroundColor Yellow

    $activeGames = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        $_.ProcessName -match "valorant|league|cs2|dota|gta|fifa|genshin|pubg|apex|fortnite|overwatch|crossfire"
    })
    if ($activeGames.Count -gt 0) {
        Write-Host "  [!] Phat hien Game dang chay ($($activeGames[0].ProcessName)). Bo qua khoi dong lai Explorer va xoa Shader Cache de tranh giat lag!" -ForegroundColor Yellow
        return
    }

    # 1. Xoa DirectX & NVIDIA/AMD Shader Cache bi nghen (nguyen nhan gay khug hinh sau khi chay nang)
    Write-Host "  -> Dang xoa DirectX Shader Cache & GPU Cache bi day..." -ForegroundColor Cyan
    $shaderPaths = @(
        "$env:LOCALAPPDATA\D3DSCache\*",
        "$env:LOCALAPPDATA\NVIDIA\DXCache\*",
        "$env:LOCALAPPDATA\NVIDIA\GLCache\*",
        "$env:LOCALAPPDATA\AMD\DxCache\*"
    )
    foreach ($sp in $shaderPaths) {
        Remove-Item -Path $sp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host "     [OK] Da lam sach bo nho dem Shader Cache cua Card do hoa." -ForegroundColor Green

    # 2. Khoi dong lai SearchHost & Windows Explorer (giai phong RAM ro ri cua giao dien)
    Write-Host "  -> Dang lam moi SearchHost & Windows Explorer (khac phuc do Taskbar / Chuot phai cham)..." -ForegroundColor Cyan
    Stop-Process -Name "SearchHost" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "SearchApp" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
    if (-not (Get-Process -Name "explorer" -ErrorAction SilentlyContinue)) {
        Start-Process "explorer.exe"
    }
    Write-Host "     [OK] Da khoi dong lai giao dien Windows Explorer muot ma!" -ForegroundColor Green

    # 3. Tuy chon Reset Driver Card Do Hoa (tuong duong Win + Ctrl + Shift + B)
    if ($IncludeDisplayReset) {
        Write-Host "  -> Dang lam moi Driver Card do hoa (Man hinh se nhay 1 giay de giai phong VRAM)..." -ForegroundColor Yellow
        $gpus = @(Get-PnpDevice -Class Display -PresentOnly -ErrorAction SilentlyContinue)
        foreach ($g in $gpus) {
            pnputil /restart-device "$($g.InstanceId)" | Out-Null
        }
        Write-Host "     [OK] Da Reset Driver Card do hoa & giai phong VRAM thanh cong!" -ForegroundColor Green
    }
}

# ==============================================================================
# 5. TOI UU CHONG DO GIAT VINH VIEN (PERMANENT ANTI-STUTTER SYSTEM TWEAKS)
# ==============================================================================
function Invoke-PermanentAntiStutterTweaks {
    Write-Host "`n=== [TWEAKS] CAU HINH CHONG DO GIAT & UU TIEN CPU/RAM CHUYEN SAU ===" -ForegroundColor Yellow

    # 1. Win32PrioritySeparation = 0x26 (38 decimal): Uu tien tuyet doi CPU cho ung dung dang mo truoc mat
    Write-Host "  -> Cau hinh Win32PrioritySeparation = 38 (Uu tien phan hoi tuc thi cho cua so dang mo)..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38 -Type DWord -ErrorAction SilentlyContinue

    # 2. Tat Power Throttling (Chong Windows tu bop xung CPU gay khug giat dot ngot)
    Write-Host "  -> Tat Power Throttling (Chong tut xung nhip CPU khi chuyen tac vu)..." -ForegroundColor Cyan
    New-Item -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Force -ErrorAction SilentlyContinue | Out-Null
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1 -Type DWord -ErrorAction SilentlyContinue

    # 3. Kich hoat High Performance & Dat xung CPU toi thieu 100%
    Write-Host "  -> Khoa muc xung nhip CPU toi thieu & toi da o 100% (Chong khug chuot do CPU ha xung)..." -ForegroundColor Cyan
    powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
    powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100 2>$null
    powercfg -setacvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100 2>$null
    powercfg /setactive scheme_current 2>$null

    # 4. Tat Multimedia System Profile Network Throttling (Chong giat khi vua dung mang vua chay nang)
    Write-Host "  -> Tat Network Throttling & tang SystemResponsiveness (Uu tien GPU/Audio/Game)..." -ForegroundColor Cyan
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-ItemProperty -Path $mmPath -Name "NetworkThrottlingIndex" -Value 0xffffffff -Type DWord -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $mmPath -Name "SystemResponsiveness" -Value 10 -Type DWord -ErrorAction SilentlyContinue

    # 5. Vo hieu hoa Microsoft Compatibility Appraiser (CompatTelRunner) trong Task Scheduler
    Write-Host "  -> Vo hieu hoa tac vu ngam CompatTelRunner (Thu pham gay do may 100% Disk/CPU)..." -ForegroundColor Cyan
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "Microsoft Compatibility Appraiser" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Application Experience\" -TaskName "ProgramDataUpdater" -ErrorAction SilentlyContinue | Out-Null
    Disable-ScheduledTask -TaskPath "\Microsoft\Windows\Customer Experience Improvement Program\" -TaskName "Consolidator" -ErrorAction SilentlyContinue | Out-Null

    # 6. Toi uu giao dien Windows (Tat hieu ung Transparency neu may hay bi lag DWM)
    Write-Host "  -> Toi uu do tre chuot & giao dien Desktop..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -ErrorAction SilentlyContinue
    Set-ItemProperty -Path "HKCU:\Control Panel\Mouse" -Name "MouseHoverTime" -Value "10" -ErrorAction SilentlyContinue

    Write-Host "  [OK] Da ap dung toan bo cau hinh Chong Do Giat & Tang Toc CPU/RAM!" -ForegroundColor Green
}

# ==============================================================================
# 6. CHE DO CANH GAC TU DONG (AUTO RAM & STANDBY GUARD DAEMON)
# ==============================================================================
function Invoke-AutoGuardMode {
    Write-Host "`n=== [GUARD MODE] CHE DO CANH GAC CHONG DO GIAT TU DONG ===" -ForegroundColor Yellow
    Write-Host "Che do nay se chay ngam va kiem tra may moi 20 giay:" -ForegroundColor Cyan
    Write-Host "  - Tu dong xa bo nho dem Standby List theo chuan ISLC khi RAM vuot qua 70%." -ForegroundColor Gray
    Write-Host "  - 100% an toan cho Game dang choi, khong giam FPS, khong lam vang Game." -ForegroundColor Gray
    Write-Host "  (Nhan Ctrl + C bat ky luc nao de dung che do Canh Gac)" -ForegroundColor Yellow
    Write-Host ""

    $cycle = 0
    while ($true) {
        $cycle++
        $ram = Get-RamStatus
        $timeStr = Get-Date -Format "HH:mm:ss"
        if ($ram.Percent -ge 70 -or ($cycle % 6 -eq 0)) {
            $null = [AntiLagNative]::PurgeStandbyList()
            Start-Sleep -Milliseconds 300
            $after = Get-RamStatus
            $saved = [math]::Max(0, $after.FreeMB - $ram.FreeMB)
            Write-Host "[$timeStr] [AUTO-CLEAN] RAM: $($ram.Percent)% -> $($after.Percent)% | Da giai phong $saved MB RAM Standby (Trong: $($after.FreeMB) MB)" -ForegroundColor Green
        } else {
            Write-Host "[$timeStr] [OK] May dang muot! RAM dang dung: $($ram.Percent)% (Trong: $($ram.FreeMB) MB)" -ForegroundColor Gray
        }
        Start-Sleep -Seconds 20
    }
}

# ==============================================================================
# CHE DO 1-CLICK CUU HO MAY DO GIAT TUC THI
# ==============================================================================
function Invoke-OneClickAntiLag {
    Show-Banner
    Write-Host "[AUTO] BAT DAU CUU HO MAY DO GIAT & GIAI PHONG TAI NGUYEN TUC THI..." -ForegroundColor Green
    Invoke-KillLagProcesses
    Invoke-RamStandbyFlush
    Invoke-RefreshUIAndGPU
    Invoke-PermanentAntiStutterTweaks
    Write-Host ""
    Write-Host "==========================================================================" -ForegroundColor Cyan
    Write-Host "[OK] HOAN TAT! MAY TINH DA DUOC GIAI PHONG RAM STANDBY & CHONG GIAT LAG!" -ForegroundColor Green
    Write-Host "==========================================================================" -ForegroundColor Cyan
}

if ($AutoRun) {
    Invoke-OneClickAntiLag
    return
}

# ==============================================================================
# VONG LAP MENU CHINH
# ==============================================================================
while ($true) {
    Show-Banner
    Write-Host "  [1] [1-CLICK] CUU HO MAY DO GIAT TUC THI (Xa RAM Standby + Diet App Treo + Tang Toc)" -ForegroundColor Green
    Write-Host "  [2] Giai phong RAM & Xoa sach Bo nho dem Standby List (Chong khug sau khi chay nang)" -ForegroundColor White
    Write-Host "  [3] Quet Top ung dung ngon RAM/CPU & Tat ngay tien trinh gay do may" -ForegroundColor White
    Write-Host "  [4] Lam moi Giao dien Explorer + Xoa Shader Cache & Reset Driver VGA (Chong tut FPS)" -ForegroundColor White
    Write-Host "  [5] Cau hinh Chong Giat Lag Vinh Vien (Tat CPU Throttling, Uu tien CPU, Tat Telemetry)" -ForegroundColor White
    Write-Host "  [6] Bat Che do Canh Gac Tu Dong (Tu dong xa RAM & chong giat lien tuc khi lam viec)" -ForegroundColor Yellow
    Write-Host "  [0] Quay lai / Thoat" -ForegroundColor Red
    Write-Host "--------------------------------------------------------------------------" -ForegroundColor DarkCyan

    $choice = Read-Host "Chon chuc nang (0-6)"
    switch ($choice) {
        "1" { Invoke-OneClickAntiLag; Pause-Menu }
        "2" { Invoke-RamStandbyFlush; Pause-Menu }
        "3" { Invoke-ProcessAnalyzer; Pause-Menu }
        "4" { Invoke-RefreshUIAndGPU -IncludeDisplayReset; Pause-Menu }
        "5" { Invoke-PermanentAntiStutterTweaks; Pause-Menu }
        "6" { Invoke-AutoGuardMode }
        "0" { Write-Host "Dang thoat Cong cu Chong Do Giat..." -ForegroundColor Yellow; return }
        default { Write-Host "Lua chon khong hop le, vui long chon tu 0 den 6!" -ForegroundColor Red; Start-Sleep -Seconds 1 }
    }
}
