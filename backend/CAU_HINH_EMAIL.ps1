$ErrorActionPreference = 'Stop'
$dotnetPath = Join-Path $env:USERPROFILE '.dotnet\dotnet.exe'
if (-not (Test-Path -LiteralPath $dotnetPath)) {
    $dotnetPath = (Get-Command dotnet -ErrorAction Stop).Source
}

Write-Host 'Cau hinh Gmail gui OTP (luu rieng tren may, khong ghi vao Git).'
Write-Host 'Can bat xac minh 2 buoc va tao Mat khau ung dung cho Gmail.'
$senderEmail = (Read-Host 'Nhap dia chi Gmail gui OTP').Trim()
if ($senderEmail -notmatch '^[^\s@]+@gmail\.com$') {
    throw 'Hay nhap dia chi @gmail.com. Script nay danh cho Gmail.'
}
$securePassword = Read-Host 'Nhap Mat khau ung dung 16 ky tu (khong phai mat khau Gmail)' -AsSecureString
$passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
try {
    $appPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) -replace '\s', ''
    if ($appPassword.Length -ne 16) {
        throw 'Mat khau ung dung Gmail can 16 ky tu. Chua luu thay doi.'
    }
    $smtpSecrets = @{
        'SmtpSettings:Host' = 'smtp.gmail.com'
        'SmtpSettings:Port' = '587'
        'SmtpSettings:EnableSsl' = 'true'
        'SmtpSettings:SenderEmail' = $senderEmail
        'SmtpSettings:SenderName' = 'NgocTruong_2380602415 Attendance'
        'SmtpSettings:Username' = $senderEmail
        'SmtpSettings:Password' = $appPassword
    }
    $secretDirectory = Join-Path $env:APPDATA 'Microsoft\UserSecrets\NgocTruong_2380602415.Api-local-settings'
    $secretPath = Join-Path $secretDirectory 'secrets.json'
    $savedSecrets = @{}
    if (Test-Path -LiteralPath $secretPath) {
        $existingSecrets = [System.IO.File]::ReadAllText($secretPath) | ConvertFrom-Json
        foreach ($property in $existingSecrets.PSObject.Properties) {
            $savedSecrets[$property.Name] = $property.Value
        }
    }
    foreach ($entry in $smtpSecrets.GetEnumerator()) { $savedSecrets[$entry.Key] = $entry.Value }
    $savedSecrets['LocalOtp:Enabled'] = 'false'
    [System.IO.Directory]::CreateDirectory($secretDirectory) | Out-Null
    [System.IO.File]::WriteAllText($secretPath, ($savedSecrets | ConvertTo-Json), [System.Text.UTF8Encoding]::new($false))
    Write-Host 'Da luu cau hinh. Dung backend bang Ctrl+C, chay lai profile http, roi bam Gui OTP trong app.' -ForegroundColor Green
    Write-Host 'Chua gui email thu. Thu muc User Secrets nam ngoai du an.'
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer)
    $appPassword = $null
    $smtpSecrets = $null
    $savedSecrets = $null
    $securePassword.Dispose()
}
