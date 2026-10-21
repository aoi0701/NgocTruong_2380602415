param(
    [switch]$RestoreLocal
)

$ErrorActionPreference = 'Stop'
$secretDirectory = Join-Path $env:APPDATA 'Microsoft\UserSecrets\NgocTruong_2380602415.Api-local-settings'
$secretPath = Join-Path $secretDirectory 'secrets.json'

# Chế độ khôi phục Local OTP thử nghiệm
if ($RestoreLocal) {
    Write-Host 'Dang bat lai che do Local OTP (ma co dinh, khong gui email that)...' -ForegroundColor Yellow
    $savedSecrets = @{}
    if (Test-Path -LiteralPath $secretPath) {
        $existing = [System.IO.File]::ReadAllText($secretPath) | ConvertFrom-Json
        foreach ($p in $existing.PSObject.Properties) {
            $savedSecrets[$p.Name] = $p.Value
        }
    }
    $savedSecrets['LocalOtp:Enabled'] = 'true'
    [System.IO.Directory]::CreateDirectory($secretDirectory) | Out-Null
    [System.IO.File]::WriteAllText($secretPath, ($savedSecrets | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Da bat lai Local OTP thanh cong.' -ForegroundColor Green
    return
}

Write-Host '=================================================================' -ForegroundColor Cyan
Write-Host '  CONG CU CAU HINH GMAIL GUI EMAIL OTP (Luu User Secrets)       ' -ForegroundColor Cyan
Write-Host '=================================================================' -ForegroundColor Cyan
Write-Host 'Thong tin duoc luu tai thu muc User Secrets cua Windows, khong ghi vao Git.' -ForegroundColor Gray
Write-Host 'Luu y: Tai khoan Gmail gui can da bat "Xac minh 2 buoc" va co "Mat khau ung dung".' -ForegroundColor Gray
Write-Host ''

$senderEmail = (Read-Host '1. Nhap dia chi Gmail gui OTP (vi du: your-name@gmail.com)').Trim()
if ($senderEmail -notmatch '^[^\s@]+@(gmail|googlemail)\.com$') {
    throw 'Dia chi email phai co duoi @gmail.com hoac @googlemail.com.'
}

$securePassword = Read-Host '2. Nhap Mat khau ung dung 16 ky tu (tao tai https://myaccount.google.com/apppasswords)' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)

try {
    $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) -replace '\s', ''
    if ($appPassword.Length -ne 16) {
        throw "Mat khau ung dung Gmail bat buoc phai co dung 16 ky tu (ban da nhap $($appPassword.Length) ky tu). Vui long thu lai."
    }

    Write-Host ''
    Write-Host 'Dang kiem tra ket noi den smtp.gmail.com:587 va gui email thu nghiem...' -ForegroundColor Cyan

    $emailOk = $false
    try {
        $smtp = [System.Net.Mail.SmtpClient]::new('smtp.gmail.com', 587)
        $smtp.EnableSsl = $true
        $smtp.DeliveryMethod = [System.Net.Mail.SmtpDeliveryMethod]::Network
        $smtp.UseDefaultCredentials = $false
        $smtp.Credentials = [System.Net.NetworkCredential]::new($senderEmail, $appPassword)
        $smtp.Timeout = 15000

        $mail = [System.Net.Mail.MailMessage]::new()
        $mail.From = [System.Net.Mail.MailAddress]::new($senderEmail, 'NgocTruong_2380602415 Attendance')
        $mail.To.Add($senderEmail)
        $mail.Subject = '[HUTECH Attendance] Kiem tra ket noi SMTP Gmail thanh cong'
        $mail.Body = "Chuc mung ban!`r`n`r`nKet noi SMTP Gmail da hoat dong chinh xac.`r`nHien tai he thong da san sang gui ma OTP that den hop thu cua nhan vien.`r`nThoi gian xac nhan: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')"
        $mail.IsBodyHtml = $false

        $smtp.Send($mail)
        $mail.Dispose()
        $smtp.Dispose()

        Write-Host "✅ XAC THUC THANH CONG! Da gui email thu nghiem toi $senderEmail." -ForegroundColor Green
        Write-Host "   Mat khau ung dung va ket noi SMTP hoat dong 100%." -ForegroundColor Green
        $emailOk = $true
    } catch {
        Write-Host "⚠️ CANH BAO: Khong the gui email thu nghiem qua Google SMTP." -ForegroundColor Red
        Write-Host "   Chi tiet loi: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "   Nguyen nhan: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        Write-Host '   Goi y: Kiem tra tai khoan da bat "Xac minh 2 buoc" chua va dung dung "Mat khau ung dung" chua.' -ForegroundColor Yellow
        
        $confirm = Read-Host 'Ban co van muon luu cau hinh nay vao User Secrets khong? (Y/N)'
        if ($confirm -notmatch '^(y|yes)$') {
            Write-Host 'Da huy thao tac, chua luu thong tin.' -ForegroundColor Yellow
            return
        }
    }

    # Luu vao User Secrets cua du an
    $smtpSecrets = @{
        'SmtpSettings:Host' = 'smtp.gmail.com'
        'SmtpSettings:Port' = '587'
        'SmtpSettings:EnableSsl' = 'true'
        'SmtpSettings:SenderEmail' = $senderEmail
        'SmtpSettings:SenderName' = 'NgocTruong_2380602415 Attendance'
        'SmtpSettings:Username' = $senderEmail
        'SmtpSettings:Password' = $appPassword
    }

    $savedSecrets = @{}
    if (Test-Path -LiteralPath $secretPath) {
        $existingSecrets = [System.IO.File]::ReadAllText($secretPath) | ConvertFrom-Json
        foreach ($property in $existingSecrets.PSObject.Properties) {
            $savedSecrets[$property.Name] = $property.Value
        }
    }
    foreach ($entry in $smtpSecrets.GetEnumerator()) {
        $savedSecrets[$entry.Key] = $entry.Value
    }
    # Tat LocalOtp khi da cau hinh email that
    $savedSecrets['LocalOtp:Enabled'] = 'false'

    [System.IO.Directory]::CreateDirectory($secretDirectory) | Out-Null
    [System.IO.File]::WriteAllText($secretPath, ($savedSecrets | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))

    Write-Host ''
    Write-Host '=================================================================' -ForegroundColor Green
    Write-Host '  DA LUU CAU HINH VAO .NET USER SECRETS THANH CONG!              ' -ForegroundColor Green
    Write-Host '=================================================================' -ForegroundColor Green
    Write-Host '1. LocalOtp da duoc TAT (LocalOtp:Enabled = false).' -ForegroundColor White
    Write-Host '2. Backend se sinh ma OTP ngau nhien va gui qua email that.' -ForegroundColor White
    Write-Host '3. Khoi dong lai backend bang lenh:' -ForegroundColor Cyan
    Write-Host '   & "$HOME\.dotnet\dotnet.exe" run --project backend/NgocTruong_2380602415.Api --launch-profile http' -ForegroundColor Cyan
    Write-Host '4. Mo app Flutter, dang ky/yeu cau OTP va kiem tra hop thu!' -ForegroundColor Cyan
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $appPassword = $null
    $smtpSecrets = $null
    $savedSecrets = $null
    $securePassword.Dispose()
}
