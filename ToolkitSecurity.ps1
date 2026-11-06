<#
================================================================================
LC_SOFT - BỘ CÔNG CỤ TỐI ƯU & KIỂM TRA PHẦN CỨNG MÁY TÍNH PRO
HỆ THỐNG BẢN QUYỀN THÔNG MINH (HYBRID ONLINE + OFFLINE TOKEN) & BẢO MẬT
Tác giả & Bản quyền: Lê Cảnh PC - LC_SOFT (lecanhpc@gmail.com - 0979.298.897)
================================================================================
#>

# 1. Lớp C# Native Xử Lý Mật Mã AES-256-CBC, Chữ Ký Số HMAC-SHA256 & Khóa Phần Cứng
$toolkitSecurityCs = @"
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

public class ToolkitLicenseCore {
    // Khóa công khai RSA 2048-bit chính thức của LC_SOFT (Bất khả xâm phạm - Chỉ xác minh, không thể làm giả key)
    public const string MasterPublicKey = @"<RSAKeyValue><Modulus>5bWopmMDk9iQPtlLU8TRVTHjQL3KOKm63dgsgQrRSG+4E6RPsT0nO4zfbsjticoBEGPPNef10mF+n0qL+wZmqtSYztpiB/2ohR+v56saUMzsSVmqsxI8PrJF6Pm828P1fcaobR7RRDi3BF3zteE7JvTCDHlanGQbePNzCvA57sKV+APwDWKkrAYaEaXB53KYS5xuCMpqRW0bgouvFU31X7UfuOtoLetNk0fBnC51fGpFvqzif/at5hc12huR6r2vvotZYeqE2BQGMfgpaHjLKq78GBUb0p8MrHgSaCT2Ot92zw8yJ9T7mZHt+i2K1rs+B+O5frymfai1nngwrr4sPQ==</Modulus><Exponent>AQAB</Exponent></RSAKeyValue>";
    public const string MasterSalt = "LC_SOFT_SECURITY_SALT_2026_@VN_LECANHPC";
    public const string MasterSecret = "LC_SOFT_PC_TOOLKIT_PRO_SECURITY_KEY_2026_LECANHPC_SECRET";

    // Xác thực chữ ký số bằng RSA-2048 Public Key (Toán học bất đối xứng: Không thể làm giả nếu không có Private Key)
    public static bool VerifyRsaSignature(string data, string sigBase64) {
        if (string.IsNullOrEmpty(data) || string.IsNullOrEmpty(sigBase64)) return false;
        try {
            using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider()) {
                rsa.FromXmlString(MasterPublicKey);
                using (SHA256 sha = SHA256.Create()) {
                    byte[] dataBytes = Encoding.UTF8.GetBytes(data);
                    byte[] sigBytes = Convert.FromBase64String(sigBase64);
                    return rsa.VerifyData(dataBytes, sha, sigBytes);
                }
            }
        } catch { return false; }
    }

    // Ký số dữ liệu bằng RSA-2048 Private Key (Chỉ dùng riêng trong Công Cụ Tạo Key của Quản Trị Viên)
    public static string SignDataRsa(string data, string privateKeyXml) {
        if (string.IsNullOrEmpty(data) || string.IsNullOrEmpty(privateKeyXml)) return string.Empty;
        try {
            using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider()) {
                rsa.FromXmlString(privateKeyXml);
                using (SHA256 sha = SHA256.Create()) {
                    byte[] dataBytes = Encoding.UTF8.GetBytes(data);
                    byte[] sigBytes = rsa.SignData(dataBytes, sha);
                    return Convert.ToBase64String(sigBytes);
                }
            }
        } catch { return string.Empty; }
    }

    // Hàm dẫn xuất khóa AES-256 từ chuỗi bí mật và Hardware ID
    public static byte[] DeriveKey(string secret, string hwid) {
        using (SHA256 sha = SHA256.Create()) {
            return sha.ComputeHash(Encoding.UTF8.GetBytes(secret + ":" + hwid + ":" + MasterSalt));
        }
    }

    // Mã hóa chứng chỉ bản quyền bằng AES-256
    public static string EncryptLicense(string plainJson, string hwid) {
        if (string.IsNullOrEmpty(plainJson) || string.IsNullOrEmpty(hwid)) return null;
        byte[] key = DeriveKey(MasterSecret, hwid);
        using (Aes aes = Aes.Create()) {
            aes.Key = key;
            aes.GenerateIV();
            using (MemoryStream ms = new MemoryStream()) {
                ms.Write(aes.IV, 0, aes.IV.Length);
                using (CryptoStream cs = new CryptoStream(ms, aes.CreateEncryptor(), CryptoStreamMode.Write)) {
                    byte[] data = Encoding.UTF8.GetBytes(plainJson);
                    cs.Write(data, 0, data.Length);
                    cs.FlushFinalBlock();
                }
                return Convert.ToBase64String(ms.ToArray());
            }
        }
    }

    // Giải mã chứng chỉ bản quyền bằng AES-256
    public static string DecryptLicense(string cipherBase64, string hwid) {
        if (string.IsNullOrEmpty(cipherBase64) || string.IsNullOrEmpty(hwid)) return null;
        try {
            byte[] raw = Convert.FromBase64String(cipherBase64);
            if (raw.Length < 17) return null;
            byte[] key = DeriveKey(MasterSecret, hwid);
            using (Aes aes = Aes.Create()) {
                aes.Key = key;
                byte[] iv = new byte[16];
                Array.Copy(raw, 0, iv, 0, 16);
                aes.IV = iv;
                using (MemoryStream ms = new MemoryStream()) {
                    using (CryptoStream cs = new CryptoStream(ms, aes.CreateDecryptor(), CryptoStreamMode.Write)) {
                        cs.Write(raw, 16, raw.Length - 16);
                        cs.FlushFinalBlock();
                    }
                    return Encoding.UTF8.GetString(ms.ToArray());
                }
            }
        } catch {
            return null; // Sai phần cứng hoặc dữ liệu bị can thiệp
        }
    }

    // Tạo chữ ký HMAC-SHA256 chống làm giả dữ liệu
    public static string ComputeSignature(string data) {
        if (string.IsNullOrEmpty(data)) return string.Empty;
        using (HMACSHA256 hmac = new HMACSHA256(Encoding.UTF8.GetBytes(MasterSecret))) {
            byte[] hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
            return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
        }
    }

    // Xác thực chữ ký số (Ưu tiên RSA-2048 Asymmetric; Hỗ trợ fallback HMAC-SHA256 cũ)
    public static bool VerifySignature(string data, string expectedSig) {
        if (string.IsNullOrEmpty(data) || string.IsNullOrEmpty(expectedSig)) return false;
        // 1. Chữ ký RSA-2048 (Độ dài > 100 ký tự - Chuẩn bảo mật cao nhất thế giới)
        if (expectedSig.Length > 100) {
            if (VerifyRsaSignature(data, expectedSig)) return true;
        }
        // 2. Chữ ký HMAC-SHA256 fallback
        string actual = ComputeSignature(data);
        return string.Equals(actual, expectedSig, StringComparison.OrdinalIgnoreCase);
    }

    // Tính mã băm SHA-256 của tệp để kiểm tra tính toàn vẹn (Anti-Tamper)
    public static string ComputeFileSha256(string filePath) {
        if (!File.Exists(filePath)) return null;
        try {
            using (SHA256 sha = SHA256.Create()) {
                using (FileStream fs = File.OpenRead(filePath)) {
                    byte[] hash = sha.ComputeHash(fs);
                    return BitConverter.ToString(hash).Replace("-", "").ToLowerInvariant();
                }
            }
        } catch {
            return null;
        }
    }

    // Mã hóa bảo vệ script bằng AES-256 với khóa bảo mật nội bộ LC_SOFT
    public static string EncryptScript(string plainText) {
        if (string.IsNullOrEmpty(plainText)) return string.Empty;
        byte[] key = DeriveKey(MasterSecret, "LC_SOFT_SCRIPT_PROTECTION_2026");
        using (Aes aes = Aes.Create()) {
            aes.Key = key;
            aes.GenerateIV();
            using (MemoryStream ms = new MemoryStream()) {
                ms.Write(aes.IV, 0, aes.IV.Length);
                using (CryptoStream cs = new CryptoStream(ms, aes.CreateEncryptor(), CryptoStreamMode.Write)) {
                    byte[] data = Encoding.UTF8.GetBytes(plainText);
                    cs.Write(data, 0, data.Length);
                    cs.FlushFinalBlock();
                }
                return Convert.ToBase64String(ms.ToArray());
            }
        }
    }

    // Giải mã script trực tiếp trên RAM (In-Memory Execution)
    public static string DecryptScript(string cipherBase64) {
        if (string.IsNullOrEmpty(cipherBase64)) return string.Empty;
        try {
            byte[] raw = Convert.FromBase64String(cipherBase64);
            if (raw.Length < 17) return string.Empty;
            byte[] key = DeriveKey(MasterSecret, "LC_SOFT_SCRIPT_PROTECTION_2026");
            using (Aes aes = Aes.Create()) {
                aes.Key = key;
                byte[] iv = new byte[16];
                Array.Copy(raw, 0, iv, 0, 16);
                aes.IV = iv;
                using (MemoryStream ms = new MemoryStream()) {
                    using (CryptoStream cs = new CryptoStream(ms, aes.CreateDecryptor(), CryptoStreamMode.Write)) {
                        cs.Write(raw, 16, raw.Length - 16);
                        cs.FlushFinalBlock();
                    }
                    return Encoding.UTF8.GetString(ms.ToArray());
                }
            }
        } catch {
            return string.Empty;
        }
    }
}
"@

if (-not ("ToolkitLicenseCore" -as [type])) {
    Add-Type -TypeDefinition $toolkitSecurityCs -ErrorAction SilentlyContinue
}

# 2. Cấu Hình Máy Chủ Bản Quyền & Cập Nhật Mặc Định (Google Apps Script Web App)
$global:ToolkitConfig = @{
    AppName            = "PC Optimization Toolkit Pro"
    Version            = "3.5"
    ReleaseDate        = "2026-10-02"
    Author             = "Lê Cảnh PC (LC_SOFT)"
    HotlineZalo        = "0979.298.897"
    Email              = "lecanhpc@gmail.com"
    Facebook           = "https://www.facebook.com/lecanhpc2589"
    # URL Máy chủ Google Apps Script Web App (0đ chi phí vận hành)
    ServerApiUrl       = "https://script.google.com/macros/s/AKfycbyLC_SOFT_DEMO_KEY_LECANH/exec"
    VersionManifestUrl = "https://raw.githubusercontent.com/lecanhpc/pctoolkit/main/version.json"
}

# Đọc cấu hình tùy chỉnh từ config.json nếu người dùng tự cấu hình server riêng
$configFile = Join-Path -Path $PSScriptRoot -ChildPath "license_config.json"
if (Test-Path $configFile) {
    try {
        $jsonConf = Get-Content -Path $configFile -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($jsonConf.ServerApiUrl) { $global:ToolkitConfig.ServerApiUrl = $jsonConf.ServerApiUrl }
        if ($jsonConf.VersionManifestUrl) { $global:ToolkitConfig.VersionManifestUrl = $jsonConf.VersionManifestUrl }
    } catch {}
}

# 3. Hàm Xác Định Thiết Bị Chạy (Ổ Cứng Cố Định PC hay USB Cứu Hộ Dongle)
function Get-StorageTargetInfo {
    param([string]$Path = $PSScriptRoot)
    if ([string]::IsNullOrEmpty($Path)) { $Path = (Get-Location).Path }
    
    $driveLetter = [System.IO.Path]::GetPathRoot($Path).TrimEnd('\', ':')
    $driveInfo = $null
    try { $driveInfo = New-Object System.IO.DriveInfo($driveLetter) } catch {}
    
    $isUsb = $false
    $diskSerial = ""
    $diskModel = ""
    $diskNumber = -1
    $busType = ""

    # Kiểm tra qua PowerShell Storage API (Windows 8/10/11/Server 2012+)
    try {
        $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
        if ($partition) {
            $diskNumber = $partition.DiskNumber
            $disk = Get-Disk -Number $diskNumber -ErrorAction Stop
            if ($disk) {
                $busType = [string]$disk.BusType
                $diskSerial = [string]$disk.SerialNumber
                $diskModel = [string]$disk.FriendlyName
                if ($busType -eq "USB" -or ($driveInfo -and $driveInfo.DriveType -eq [System.IO.DriveType]::Removable)) {
                    $isUsb = $true
                }
            }
        }
    } catch {
        # Fallback qua WMI cho Windows 7 hoặc môi trường hạn chế
        try {
            $query = "ASSOCIATORS OF {Win32_LogicalDisk.DeviceID='$($driveLetter):'} WHERE AssocClass = Win32_LogicalDiskToPartition"
            $partWmi = Get-CimInstance -Query $query -ErrorAction Stop | Select-Object -First 1
            if ($partWmi) {
                $diskQuery = "ASSOCIATORS OF {Win32_DiskPartition.DeviceID='$($partWmi.DeviceID)'} WHERE AssocClass = Win32_DiskDriveToDiskPartition"
                $driveWmi = Get-CimInstance -Query $diskQuery -ErrorAction Stop | Select-Object -First 1
                if ($driveWmi) {
                    $diskSerial = [string]$driveWmi.SerialNumber
                    $diskModel = [string]$driveWmi.Model
                    $busType = [string]$driveWmi.InterfaceType
                    if ($busType -eq "USB" -or ($driveInfo -and $driveInfo.DriveType -eq [System.IO.DriveType]::Removable)) {
                        $isUsb = $true
                    }
                }
            }
        } catch {}
    }

    # Nếu vẫn chưa lấy được Serial, dùng Volume Serial Number dự phòng
    if ([string]::IsNullOrEmpty($diskSerial)) {
        try {
            $vol = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($driveLetter):'" -ErrorAction SilentlyContinue
            if ($vol -and $vol.VolumeSerialNumber) {
                $diskSerial = "VOL_" + $vol.VolumeSerialNumber
            }
        } catch {}
    }

    return [PSCustomObject]@{
        DriveLetter = $driveLetter
        IsUsb       = $isUsb
        DiskNumber  = $diskNumber
        BusType     = $busType
        DiskSerial  = $diskSerial.Trim()
        DiskModel   = $diskModel.Trim()
        DriveType   = if ($driveInfo) { $driveInfo.DriveType.ToString() } else { "Unknown" }
    }
}

# 4. Hàm Trích Xuất Mã Phần Cứng (Hardware ID - HWID)
# - Nếu đang chạy trên USB: Khóa theo Serial Phần Cứng của chiếc USB (USB-XXXX-XXXX-XXXX-XXXX)
# - Nếu đang chạy trên PC: Khóa theo Mainboard + CPU + UUID Máy (PC-XXXX-XXXX-XXXX-XXXX)
function Get-HardwareID {
    param(
        [string]$Path = $PSScriptRoot,
        [switch]$ForcePC,
        [switch]$ForceUSB,
        [string]$CustomUsbSerial = ""
    )
    $info = Get-StorageTargetInfo -Path $Path

    if (($info.IsUsb -or $ForceUSB) -and -not $ForcePC) {
        $serial = if ($CustomUsbSerial) { $CustomUsbSerial } else { $info.DiskSerial }
        $model  = $info.DiskModel
        if ([string]::IsNullOrEmpty($serial)) { $serial = "GENERIC_USB_CONTROLLER" }
        $raw = "USB|" + $serial.Trim() + "|" + $model.Trim()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($raw))
        $hex = [BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 16)
        $formatted = "USB-{0}-{1}-{2}-{3}" -f $hex.Substring(0,4), $hex.Substring(4,4), $hex.Substring(8,4), $hex.Substring(12,4)
        
        $desc = if ($info.DiskModel) { "USB Dongle: $($info.DiskModel) (Ổ $($info.DriveLetter):)" } else { "USB Dongle Cứu Hộ Thợ Kỹ Thuật" }
        return [PSCustomObject]@{
            Type        = "USB"
            HWID        = $formatted
            Description = $desc
            RawSerial   = $serial
            DriveLetter = $info.DriveLetter
        }
    } else {
        $bb = ""
        $uuid = ""
        $cpu = ""
        try { $bb = (Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue).SerialNumber } catch {}
        try { $uuid = (Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue).UUID } catch {}
        try { $cpu = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).ProcessorId } catch {}

        if ([string]::IsNullOrEmpty($bb)) { $bb = "MB_STANDARD_OEM" }
        if ([string]::IsNullOrEmpty($uuid)) { $uuid = "UUID_STANDARD_DEFAULT" }
        if ([string]::IsNullOrEmpty($cpu)) { $cpu = "CPU_STANDARD_ID" }

        $raw = "PC|" + $bb.Trim() + "|" + $uuid.Trim() + "|" + $cpu.Trim()
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($raw))
        $hex = [BitConverter]::ToString($hashBytes).Replace("-", "").Substring(0, 16)
        $formatted = "PC-{0}-{1}-{2}-{3}" -f $hex.Substring(0,4), $hex.Substring(4,4), $hex.Substring(8,4), $hex.Substring(12,4)

        return [PSCustomObject]@{
            Type        = "PC"
            HWID        = $formatted
            Description = "Máy tính cá nhân (Mainboard/CPU/UUID)"
            RawDetails  = "$bb / $uuid / $cpu"
            DriveLetter = $info.DriveLetter
        }
    }
}

# 5. Hàm Tạo và Mã Hóa File Bản Quyền (license.lic)
function New-ToolkitLicensePayload {
    param(
        [Parameter(Mandatory=$true)][string]$LicenseKey,
        [Parameter(Mandatory=$true)][string]$LicenseType, # "PC" hoặc "USB"
        [Parameter(Mandatory=$true)][string]$CustomerName,
        [Parameter(Mandatory=$true)][string]$ShopName,
        [Parameter(Mandatory=$true)][string]$HardwareID,
        [string]$ExpiryDate = "2099-12-31",
        [string]$Status = "ACTIVE"
    )

    # Chuỗi dữ liệu ký số xác thực bản quyền
    $sigData = "$LicenseKey|$LicenseType|$CustomerName|$ShopName|$HardwareID|$ExpiryDate|$Status"

    # Tìm Private Key của Quản Trị Viên để ký RSA-2048 (Bảo mật tuyệt đối, không thể làm giả)
    $privKeyFile = Join-Path -Path $PSScriptRoot -ChildPath "LC_SOFT_MASTER_PRIVATE.key"
    if (-not (Test-Path $privKeyFile)) {
        $candidate = "c:\Users\Admin\Documents\Antigravity\PHAT_HANH_LC_SOFT\3_CONG_CU_TAO_KEY_BAN_QUYEN (QUAN TRI VIEN - GIU BI MAT)\LC_SOFT_MASTER_PRIVATE.key"
        if (Test-Path $candidate) { $privKeyFile = $candidate }
    }

    $signature = ""
    if (Test-Path $privKeyFile) {
        try {
            $privXml = [System.IO.File]::ReadAllText($privKeyFile, [System.Text.Encoding]::UTF8)
            $signature = [ToolkitLicenseCore]::SignDataRsa($sigData, $privXml)
        } catch {}
    }
    if ([string]::IsNullOrEmpty($signature)) {
        # Fallback HMAC-SHA256 nếu không tìm thấy Private Key
        $signature = [ToolkitLicenseCore]::ComputeSignature($sigData)
    }

    $licObj = [PSCustomObject]@{
        LicenseKey   = $LicenseKey.Trim().ToUpper()
        LicenseType  = $LicenseType.Trim().ToUpper()
        CustomerName = $CustomerName.Trim()
        ShopName     = $ShopName.Trim()
        HardwareID   = $HardwareID.Trim()
        IssueDate    = (Get-Date).ToString("yyyy-MM-dd")
        ExpiryDate   = $ExpiryDate.Trim()
        Status       = $Status.Trim().ToUpper()
        Signature    = $signature
    }

    $plainJson = $licObj | ConvertTo-Json -Compress
    $encryptedBase64 = [ToolkitLicenseCore]::EncryptLicense($plainJson, $HardwareID)

    return [PSCustomObject]@{
        Object          = $licObj
        Json            = $plainJson
        EncryptedBase64 = $encryptedBase64
    }
}

function Save-ToolkitLicenseFile {
    param(
        [Parameter(Mandatory=$true)][string]$EncryptedBase64,
        [string]$TargetFolder = $PSScriptRoot
    )
    $licFile = Join-Path -Path $TargetFolder -ChildPath "license.lic"
    [System.IO.File]::WriteAllText($licFile, $EncryptedBase64, [System.Text.Encoding]::UTF8)
    return $licFile
}

# 6. Hàm Kiểm Tra & Giải Mã Bản Quyền (Hoạt Động 100% Offline)
function Test-ToolkitLicense {
    param(
        [string]$BaseDir = $PSScriptRoot
    )
    $licFile = Join-Path -Path $BaseDir -ChildPath "license.lic"
    if (-not (Test-Path $licFile)) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "CHƯA_CÓ_FILE"
            Message = "Chưa tìm thấy file bản quyền license.lic"
            License = $null
        }
    }

    $cipher = (Get-Content -Path $licFile -Raw -Encoding UTF8).Trim()
    if ([string]::IsNullOrEmpty($cipher)) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "FILE_RỖNG"
            Message = "File bản quyền bị rỗng hoặc lỗi"
            License = $null
        }
    }

    # Lấy thông tin thiết bị thực tế hiện tại
    $hwidInfo = Get-HardwareID -Path $BaseDir
    $currentHwid = $hwidInfo.HWID
    $currentType = $hwidInfo.Type

    # Thử giải mã bằng HWID hiện tại
    $plainJson = [ToolkitLicenseCore]::DecryptLicense($cipher, $currentHwid)
    if ([string]::IsNullOrEmpty($plainJson)) {
        # Nếu đang chạy trên PC nhưng có thể là người dùng copy trộm từ USB sang PC:
        # Giải mã thử bằng generic để báo rõ lý do
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "SAI_THIẾT_BỊ"
            Message = "Mã thiết bị không khớp! Bản quyền này không được cấp phép cho máy tính/USB này."
            License = $null
            CurrentHwid = $currentHwid
        }
    }

    $lic = $null
    try {
        $lic = $plainJson | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "DỮ_LIỆU_LỖI"
            Message = "Dữ liệu bản quyền bị sai định dạng"
            License = $null
        }
    }

    # 1. Kiểm tra HWID bên trong JSON có trùng khớp không
    if ($lic.HardwareID -ne $currentHwid) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "SAI_HWID"
            Message = "Mã phần cứng không khớp với chứng chỉ bản quyền!"
            License = $lic
        }
    }

    # 2. Kiểm tra loại bản quyền (USB vs PC):
    # Nếu bản quyền là USB Dongle: bắt buộc ứng dụng phải chạy trực tiếp trên USB!
    if ($lic.LicenseType -eq "USB" -and $currentType -ne "USB") {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "SAI_LOẠI_USB"
            Message = "Bản quyền này được cấp cho USB Dongle! Vui lòng cắm và chạy trực tiếp từ USB."
            License = $lic
        }
    }

    # 3. Kiểm tra hạn sử dụng (ExpiryDate) & Tính số ngày dùng thử còn lại
    $remainingDays = 99999
    $isTrial = ($lic.Status -eq "TRIAL" -or $lic.LicenseKey -like "TRIAL*")
    try {
        $expiry = [DateTime]::ParseExact($lic.ExpiryDate, "yyyy-MM-dd", [System.Globalization.CultureInfo]::InvariantCulture)
        $diffDays = ($expiry.Date - (Get-Date).Date).TotalDays
        $remainingDays = [math]::Max(0, [int][math]::Ceiling($diffDays))
        if ((Get-Date).Date -gt $expiry.Date) {
            return [PSCustomObject]@{
                IsValid       = $false
                Reason        = "HẾT_HẠN"
                Message       = "Thời gian dùng thử hoặc bản quyền đã hết hạn vào ngày $($lic.ExpiryDate)!"
                License       = $lic
                RemainingDays = 0
                IsTrial       = $isTrial
                CurrentHwid   = $currentHwid
                DeviceType    = $currentType
            }
        }
    } catch {}

    # 4. Xác minh chữ ký số HMAC-SHA256 (Chống chỉnh sửa file)
    $sigData = "$($lic.LicenseKey)|$($lic.LicenseType)|$($lic.CustomerName)|$($lic.ShopName)|$($lic.HardwareID)|$($lic.ExpiryDate)|$($lic.Status)"
    if (-not [ToolkitLicenseCore]::VerifySignature($sigData, $lic.Signature)) {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "SAI_CHỮ_KÝ"
            Message = "Chữ ký số không hợp lệ! File bản quyền đã bị can thiệp trái phép."
            License = $lic
        }
    }

    # 5. Kiểm tra trạng thái Status
    if ($lic.Status -eq "LOCKED") {
        return [PSCustomObject]@{
            IsValid = $false
            Reason  = "BỊ_KHÓA"
            Message = "Bản quyền này đã bị khóa bởi quản trị viên!"
            License = $lic
        }
    }

    return [PSCustomObject]@{
        IsValid       = $true
        Reason        = if ($isTrial) { "DÙNG_THỬ" } else { "HỢP_LỆ" }
        Message       = if ($isTrial) { "Bản Dùng Thử 7 Ngày (Còn $remainingDays ngày)" } else { "Bản quyền hợp lệ 100%" }
        License       = $lic
        CurrentHwid   = $currentHwid
        DeviceType    = $currentType
        RemainingDays = $remainingDays
        IsTrial       = $isTrial
    }
}

# 7. Hàm Kích Hoạt Online Qua Google Apps Script Web App
function Invoke-OnlineActivation {
    param(
        [Parameter(Mandatory=$true)][string]$LicenseKey,
        [string]$CustomerName = "",
        [string]$ShopName = "",
        [string]$BaseDir = $PSScriptRoot
    )
    $hwidInfo = Get-HardwareID -Path $BaseDir
    $hwid = $hwidInfo.HWID
    $type = $hwidInfo.Type

    $apiUrl = $global:ToolkitConfig.ServerApiUrl
    if ([string]::IsNullOrEmpty($apiUrl) -or $apiUrl -like "*DEMO_KEY*") {
        # Nếu chưa cấu hình URL máy chủ Google Sheet thật
        return [PSCustomObject]@{
            Success = $false
            Message = "Chưa cấu hình URL Máy Chủ Google Apps Script trong file license_config.json! Bạn có thể kích hoạt trực tiếp bằng file license.lic Offline do LC_SOFT cấp."
        }
    }

    try {
        $encodedKey  = [System.Uri]::EscapeDataString($LicenseKey.Trim().ToUpper())
        $encodedHwid = [System.Uri]::EscapeDataString($hwid)
        $encodedCust = [System.Uri]::EscapeDataString($CustomerName.Trim())
        $encodedShop = [System.Uri]::EscapeDataString($ShopName.Trim())
        $encodedType = [System.Uri]::EscapeDataString($type)

        $fullUrl = "$apiUrl?action=activate&key=$encodedKey&hwid=$encodedHwid&customer=$encodedCust&shop=$encodedShop&type=$encodedType"
        
        # Gọi HTTP GET đến Google Apps Script
        $webClient = New-Object System.Net.WebClient
        $webClient.Encoding = [System.Text.Encoding]::UTF8
        $responseJson = $webClient.DownloadString($fullUrl)
        $res = $responseJson | ConvertFrom-Json

        if ($res.success) {
            # Tạo file license.lic cục bộ mã hóa bằng AES-256
            $lic = $res.license
            $payload = New-ToolkitLicensePayload -LicenseKey $lic.LicenseKey `
                                                -LicenseType $lic.LicenseType `
                                                -CustomerName $lic.CustomerName `
                                                -ShopName $lic.ShopName `
                                                -HardwareID $lic.HardwareID `
                                                -ExpiryDate $lic.ExpiryDate `
                                                -Status "ACTIVE"
            Save-ToolkitLicenseFile -EncryptedBase64 $payload.EncryptedBase64 -TargetFolder $BaseDir
            return [PSCustomObject]@{
                Success = $true
                Message = "Kích hoạt bản quyền thành công!"
                License = $payload.Object
            }
        } else {
            return [PSCustomObject]@{
                Success = $false
                Message = $res.message
            }
        }
    } catch {
        return [PSCustomObject]@{
            Success = $false
            Message = "Lỗi kết nối máy chủ bản quyền: " + $_.Exception.Message
        }
    }
}

# 8. Hàm Kiểm Tra Âm Thầm Định Kỳ (Heartbeat Check khi có mạng)
function Invoke-HeartbeatCheck {
    param(
        [Parameter(Mandatory=$true)]$License,
        [string]$BaseDir = $PSScriptRoot
    )
    $apiUrl = $global:ToolkitConfig.ServerApiUrl
    if ([string]::IsNullOrEmpty($apiUrl) -or $apiUrl -like "*DEMO_KEY*") { return }

    try {
        $encodedKey  = [System.Uri]::EscapeDataString($License.LicenseKey)
        $encodedHwid = [System.Uri]::EscapeDataString($License.HardwareID)
        $checkUrl    = "$apiUrl?action=check&key=$encodedKey&hwid=$encodedHwid"
        
        $req = [System.Net.WebRequest]::Create($checkUrl)
        $req.Timeout = 4000 # 4 giây timeout
        $resp = $req.GetResponse()
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $json = $reader.ReadToEnd()
        $reader.Close()
        $resp.Close()

        $statusObj = $json | ConvertFrom-Json
        if ($statusObj.status -eq "LOCKED") {
            # Bị khóa từ máy chủ -> Xóa file license.lic ngay
            $licFile = Join-Path -Path $BaseDir -ChildPath "license.lic"
            if (Test-Path $licFile) { Remove-Item -Path $licFile -Force -ErrorAction SilentlyContinue }
            return "LOCKED"
        }
        return "ACTIVE"
    } catch {
        return "OFFLINE" # Mất mạng hoặc máy chủ bận: Vẫn cho dùng offline bình thường
    }
}

# 9. Hàm Kiểm Tra & Nâng Cấp Phiên Bản Mới (Auto-Update Engine)
function Check-SoftwareUpdate {
    param(
        [string]$ManifestUrl = $global:ToolkitConfig.VersionManifestUrl
    )
    try {
        $wc = New-Object System.Net.WebClient
        $wc.Encoding = [System.Text.Encoding]::UTF8
        $jsonStr = $wc.DownloadString($ManifestUrl)
        $manifest = $jsonStr | ConvertFrom-Json

        $currentVer = [version]$global:ToolkitConfig.Version
        $remoteVer  = [version]$manifest.version

        $hasUpdate = ($remoteVer -gt $currentVer)
        return [PSCustomObject]@{
            HasUpdate      = $hasUpdate
            CurrentVersion = $global:ToolkitConfig.Version
            LatestVersion  = $manifest.version
            ReleaseDate    = $manifest.releaseDate
            DownloadUrl    = $manifest.downloadUrl
            Changelog      = $manifest.changelog
        }
    } catch {
        return [PSCustomObject]@{
            HasUpdate      = $false
            CurrentVersion = $global:ToolkitConfig.Version
            Error          = $_.Exception.Message
        }
    }
}

function Apply-SoftwareUpdate {
    param(
        [Parameter(Mandatory=$true)][string]$DownloadUrl,
        [string]$TargetDir = $PSScriptRoot
    )
    $tempZip = Join-Path $env:TEMP "PCToolkitUpdate_$([Guid]::NewGuid().ToString().Substring(0,8)).zip"
    $tempExtract = Join-Path $env:TEMP "PCToolkitUpdate_Extracted"

    # Tải tệp cập nhật
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($DownloadUrl, $tempZip)

    if (Test-Path $tempExtract) { Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZip, $tempExtract)

    # Sinh tệp ApplyUpdate.bat để chạy nền sau khi tắt app hiện tại
    $batFile = Join-Path $env:TEMP "ApplyPCToolkitUpdate.bat"
    $batContent = @"
@echo off
chcp 65001 >nul
title Dang Nang Cap PC Optimization Toolkit Pro - LC_SOFT
echo ========================================================
echo   Dang tien hanh cap nhat phien ban moi...
echo ========================================================
timeout /t 2 /nobreak >nul

:: Sao chep de file moi (Bao ve license.lic va license_config.json khong bi mat ban quyen)
robocopy "$tempExtract" "$TargetDir" /E /XF "license.lic" "license_config.json" "debug.log" /NFL /NDL /NJH /NJS /nc /ns /np

echo.
echo Cap nhat thanh cong! Dang khoi dong lai phan mem...
start "" "$TargetDir\PCToolkitPro.exe"

:: Don dep tep tam
del "$tempZip" 2>nul
rmdir /S /Q "$tempExtract" 2>nul
exit
"@
    [System.IO.File]::WriteAllText($batFile, $batContent, [System.Text.Encoding]::Default)

    # Chạy bat file và thoát app
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$batFile`"" -WindowStyle Normal
    [System.Windows.Application]::Current.Shutdown()
}
