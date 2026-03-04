param(
  [string]$DeviceId = "",
  [Parameter(Mandatory = $true)]
  [string]$Phone,
  [Parameter(Mandatory = $true)]
  [string]$Password,
  [string]$PackageName = "org.hataykuryeler.hkd",
  [int]$StepDelayMs = 1400
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Get-AdbPrefix {
  param([string]$TargetDeviceId)
  if ([string]::IsNullOrWhiteSpace($TargetDeviceId)) {
    return "adb"
  }
  return "adb -s $TargetDeviceId"
}

function Invoke-Adb {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Command
  )

  $adb = Get-AdbPrefix -TargetDeviceId $DeviceId
  $full = "$adb $Command 2>nul"
  return (cmd /c $full)
}

function Start-App {
  Write-Host "[SMOKE] Uygulama baslatiliyor..."
  Invoke-Adb -Command "shell am force-stop $PackageName" | Out-Null
  Start-Sleep -Milliseconds 500
  Invoke-Adb -Command "shell monkey -p $PackageName -c android.intent.category.LAUNCHER 1" | Out-Null
  Start-Sleep -Milliseconds $StepDelayMs
}

function Get-UiXml {
  Invoke-Adb -Command "shell uiautomator dump /sdcard/window_dump.xml" | Out-Null
  return (Invoke-Adb -Command "shell cat /sdcard/window_dump.xml" | Out-String)
}

function Get-BoundsByNeedle {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Xml,
    [Parameter(Mandatory = $true)]
    [string]$Needle
  )

  $escaped = [regex]::Escape($Needle)
  $pattern = "content-desc=""[^""]*$escaped[^""]*""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]"""
  $match = [regex]::Match($Xml, $pattern)
  if (-not $match.Success) {
    $patternText = "text=""[^""]*$escaped[^""]*""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]"""
    $match = [regex]::Match($Xml, $patternText)
  }
  if (-not $match.Success) {
    return $null
  }

  return @{
    X1 = [int]$match.Groups[1].Value
    Y1 = [int]$match.Groups[2].Value
    X2 = [int]$match.Groups[3].Value
    Y2 = [int]$match.Groups[4].Value
  }
}

function Get-EditTextBoundsByIndex {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Xml,
    [int]$Index = 0
  )

  $matches = [regex]::Matches(
    $Xml,
    "class=""android\.widget\.EditText""[^>]*bounds=""\[(\d+),(\d+)\]\[(\d+),(\d+)\]"""
  )
  if ($matches.Count -le $Index) {
    return $null
  }

  $match = $matches[$Index]
  return @{
    X1 = [int]$match.Groups[1].Value
    Y1 = [int]$match.Groups[2].Value
    X2 = [int]$match.Groups[3].Value
    Y2 = [int]$match.Groups[4].Value
  }
}

function Get-PhoneEditTextBounds {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Xml
  )

  $matches = [regex]::Matches(
    $Xml,
    'class="android\.widget\.EditText"[^>]*password="false"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  )
  if ($matches.Count -eq 0) {
    return Get-EditTextBoundsByIndex -Xml $Xml -Index 0
  }

  $selected = $matches[0]
  foreach ($item in $matches) {
    if ([int]$item.Groups[2].Value -lt [int]$selected.Groups[2].Value) {
      $selected = $item
    }
  }

  return @{
    X1 = [int]$selected.Groups[1].Value
    Y1 = [int]$selected.Groups[2].Value
    X2 = [int]$selected.Groups[3].Value
    Y2 = [int]$selected.Groups[4].Value
  }
}

function Get-PasswordEditTextBounds {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Xml
  )

  $match = [regex]::Match(
    $Xml,
    'class="android\.widget\.EditText"[^>]*password="true"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  )
  if ($match.Success) {
    return @{
      X1 = [int]$match.Groups[1].Value
      Y1 = [int]$match.Groups[2].Value
      X2 = [int]$match.Groups[3].Value
      Y2 = [int]$match.Groups[4].Value
    }
  }

  $fallback = Get-EditTextBoundsByIndex -Xml $Xml -Index 1
  if ($null -ne $fallback) {
    return $fallback
  }

  return $null
}

function Wait-ForPostLogin {
  param(
    [int]$TimeoutSeconds = 14
  )

  for ($i = 0; $i -lt $TimeoutSeconds; $i++) {
    $xml = Get-UiXml
    if ($xml -match [regex]::Escape("HAMOKDER Ana Sayfa")) {
      return @{
        Success = $true
        Xml = $xml
      }
    }
    if (
      $xml -match [regex]::Escape("Giris dogrulanamadi") -or
      $xml -match [regex]::Escape("Giris basarisiz") -or
      $xml -match [regex]::Escape("Telefon veya sifre")
    ) {
      return @{
        Success = $false
        Xml = $xml
        Error = "Giris basarisiz: Telefon veya sifre kontrolu gerekiyor."
      }
    }
    Start-Sleep -Milliseconds 900
  }

  return @{
    Success = $false
    Xml = (Get-UiXml)
    Error = "Giris tamamlanamadi: Ana sayfa acilmadi."
  }
}

function Ensure-PasswordMode {
  $xml = Get-UiXml
  if ($xml -match 'content-desc="Sifre"[^>]*checked="false"') {
    $sifreRadio = Get-BoundsByNeedle -Xml $xml -Needle "Sifre"
    if ($null -ne $sifreRadio) {
      Tap-BoundsCenter -Bounds $sifreRadio
      Start-Sleep -Milliseconds 350
    }
  }
}

function Ensure-LoginReady {
  for ($i = 0; $i -lt 16; $i++) {
    $xml = Get-UiXml
    if ($xml -match [regex]::Escape("HAMOKDER Ana Sayfa")) {
      return @{
        Ready = $true
        IsHome = $true
        Xml = $xml
      }
    }
    if ($xml -match [regex]::Escape("Giris Yap")) {
      return @{
        Ready = $true
        IsHome = $false
        Xml = $xml
      }
    }
    Start-Sleep -Milliseconds 500
  }

  return @{
    Ready = $false
    IsHome = $false
    Xml = (Get-UiXml)
  }
}

function Get-EditTextTextByIndex {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Xml,
    [int]$Index = 0
  )

  $matches = [regex]::Matches(
    $Xml,
    'class="android\.widget\.EditText"[^>]*text="([^"]*)"'
  )
  if ($matches.Count -le $Index) {
    return $null
  }

  return $matches[$Index].Groups[1].Value
}

function Tap-BoundsCenter {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Bounds
  )

  $x = [int](($Bounds.X1 + $Bounds.X2) / 2)
  $y = [int](($Bounds.Y1 + $Bounds.Y2) / 2)
  Invoke-Adb -Command "shell input tap $x $y" | Out-Null
  Start-Sleep -Milliseconds 300
}

function Swipe-Up {
  Invoke-Adb -Command "shell input swipe 540 1900 540 650 260" | Out-Null
  Start-Sleep -Milliseconds 450
}

function Fill-Input {
  param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Bounds,
    [Parameter(Mandatory = $true)]
    [string]$Value
  )

  Tap-BoundsCenter -Bounds $Bounds
  Invoke-Adb -Command "shell input keyevent 123" | Out-Null
  for ($i = 0; $i -lt 18; $i++) {
    Invoke-Adb -Command "shell input keyevent 67" | Out-Null
  }

  $sanitized = $Value
  $sanitized = $sanitized -replace " ", "%s"
  $sanitized = $sanitized -replace "\(", "\\("
  $sanitized = $sanitized -replace "\)", "\\)"
  $sanitized = $sanitized -replace "&", "\\&"
  $sanitized = $sanitized -replace "\|", "\\|"
  $sanitized = $sanitized -replace "<", "\\<"
  $sanitized = $sanitized -replace ">", "\\>"
  $sanitized = $sanitized -replace ";", "\\;"
  $sanitized = $sanitized -replace "'", "\\'"
  $sanitized = $sanitized -replace '"', '\"'
  Invoke-Adb -Command "shell input text $sanitized" | Out-Null
  Start-Sleep -Milliseconds 900
}

function Assert-Contains {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Xml,
    [Parameter(Mandatory = $true)]
    [string]$Needle,
    [Parameter(Mandatory = $true)]
    [string]$StepLabel
  )

  if ($Xml -notmatch [regex]::Escape($Needle)) {
    throw "[SMOKE][FAIL] $StepLabel -> '$Needle' bulunamadi."
  }
  Write-Host "[SMOKE][OK] $StepLabel"
}

function Open-Card-And-Back {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CardNeedle,
    [Parameter(Mandatory = $true)]
    [string]$ScreenNeedle
  )

  $xml = Get-UiXml
  $bounds = Get-BoundsByNeedle -Xml $xml -Needle $CardNeedle
  for ($i = 0; $null -eq $bounds -and $i -lt 4; $i++) {
    Swipe-Up
    $xml = Get-UiXml
    $bounds = Get-BoundsByNeedle -Xml $xml -Needle $CardNeedle
  }
  if ($null -eq $bounds) {
    throw "[SMOKE][FAIL] Home karti bulunamadi: $CardNeedle"
  }

  Tap-BoundsCenter -Bounds $bounds
  Start-Sleep -Milliseconds $StepDelayMs

  $screenXml = Get-UiXml
  Assert-Contains -Xml $screenXml -Needle $ScreenNeedle -StepLabel "$CardNeedle ekrani"

  Invoke-Adb -Command "shell input keyevent 4" | Out-Null
  Start-Sleep -Milliseconds $StepDelayMs

  $homeXml = Get-UiXml
  Assert-Contains -Xml $homeXml -Needle "HAMOKDER Ana Sayfa" -StepLabel "$CardNeedle geri donus"
}

Write-Host "[SMOKE] HKD cihaz smoke testi basladi."

$devices = (adb devices | Select-String -Pattern "device$").Line
if ([string]::IsNullOrWhiteSpace($devices)) {
  throw "[SMOKE][FAIL] Bagli cihaz bulunamadi."
}

Start-App

$readyState = Ensure-LoginReady
if (-not $readyState.Ready) {
  throw "[SMOKE][FAIL] Uygulama acilisinda login veya ana sayfa gorunmedi."
}

$xml = $readyState.Xml
if ($readyState.IsHome) {
  Write-Host "[SMOKE][INFO] Uygulama acilista oturum acik geldi, login adimi atlandi."
} else {
  Assert-Contains -Xml $xml -Needle "Hatay Kuryeler Dernegi" -StepLabel "Login acilis"
  Assert-Contains -Xml $xml -Needle "Giris Yap" -StepLabel "Login butonu"
  Ensure-PasswordMode

  $phoneBounds = Get-PhoneEditTextBounds -Xml $xml
  if ($null -eq $phoneBounds) {
    throw "[SMOKE][FAIL] Login input alanlari bulunamadi."
  }

  Fill-Input -Bounds $phoneBounds -Value $Phone
  $xmlAfterPhone = Get-UiXml
  $phoneText = Get-EditTextTextByIndex -Xml $xmlAfterPhone -Index 0
  Write-Host "[SMOKE][DEBUG] Telefon alani: '$phoneText'"
  $passBounds = $null
  for ($retry = 0; $retry -lt 6; $retry++) {
    $passBounds = Get-PasswordEditTextBounds -Xml $xmlAfterPhone
    if ($null -ne $passBounds) {
      break
    }
    Start-Sleep -Milliseconds 350
    $xmlAfterPhone = Get-UiXml
  }
  if ($null -eq $passBounds) {
    throw "[SMOKE][FAIL] Sifre alani bulunamadi."
  }
  Fill-Input -Bounds $passBounds -Value $Password
  $xmlAfterPassword = Get-UiXml
  $passwordText = Get-EditTextTextByIndex -Xml $xmlAfterPassword -Index 1
  Write-Host "[SMOKE][DEBUG] Sifre alani uzunluk: $($passwordText.Length)"
  Invoke-Adb -Command "shell input keyevent 4" | Out-Null
  Start-Sleep -Milliseconds 1200

  $loginButton = Get-BoundsByNeedle -Xml (Get-UiXml) -Needle "Giris Yap"
  if ($null -eq $loginButton) {
    throw "[SMOKE][FAIL] Giris butonu tap icin bulunamadi."
  }
  Tap-BoundsCenter -Bounds $loginButton
  Start-Sleep -Milliseconds 1000

  $postLogin = Wait-ForPostLogin
  if (-not $postLogin.Success) {
    throw "[SMOKE][FAIL] $($postLogin.Error)"
  }
  Assert-Contains -Xml $postLogin.Xml -Needle "HAMOKDER Ana Sayfa" -StepLabel "Login sonrasi ana sayfa"
}

Open-Card-And-Back -CardNeedle "Duyurular" -ScreenNeedle "Duyurular"
Open-Card-And-Back -CardNeedle "Etkinlikler" -ScreenNeedle "Etkinlikler"
Open-Card-And-Back -CardNeedle "Profil" -ScreenNeedle "Profil"
Open-Card-And-Back -CardNeedle "Aidat Durumu" -ScreenNeedle "Aidat Durumu"
Open-Card-And-Back -CardNeedle "Bildirimler" -ScreenNeedle "Bildirimler"
Open-Card-And-Back -CardNeedle "Destek Merkezi" -ScreenNeedle "Destek Merkezi"
Open-Card-And-Back -CardNeedle "Is Pazari" -ScreenNeedle "Is Pazari"
Open-Card-And-Back -CardNeedle "Organizasyon" -ScreenNeedle "Organizasyon Paneli"
Open-Card-And-Back -CardNeedle "Yonetim Paneli" -ScreenNeedle "Yonetim Paneli"

$homeXml = Get-UiXml
$logoutBounds = Get-BoundsByNeedle -Xml $homeXml -Needle "Cikis"
for ($i = 0; $null -eq $logoutBounds -and $i -lt 4; $i++) {
  Invoke-Adb -Command "shell input swipe 540 700 540 1900 260" | Out-Null
  Start-Sleep -Milliseconds 350
  $homeXml = Get-UiXml
  $logoutBounds = Get-BoundsByNeedle -Xml $homeXml -Needle "Cikis"
}
if ($null -eq $logoutBounds) {
  throw "[SMOKE][FAIL] Cikis butonu bulunamadi."
}
Tap-BoundsCenter -Bounds $logoutBounds
Start-Sleep -Milliseconds $StepDelayMs

$afterLogout = Get-UiXml
Assert-Contains -Xml $afterLogout -Needle "Hatay Kuryeler Dernegi" -StepLabel "Logout sonrasi login"

Write-Host "[SMOKE][PASS] HKD cihaz smoke testi basariyla tamamlandi."
