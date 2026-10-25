# Read-only diagnostic helper for DEXP Android TV / CleanYourTV.
# It does not disable packages or modify TV settings.

$ErrorActionPreference = 'Stop'
if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
    Write-Error 'adb не найден. Установите Android Platform Tools и добавьте adb в PATH.'
    exit 1
}

$tvIp = Read-Host 'Введите IP-адрес телевизора из сетевых настроек (например, 192.168.1.50)'
$parsed = $null
$valid = [System.Net.IPAddress]::TryParse($tvIp, [ref]$parsed)
if (-not $valid -or $parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
    Write-Error 'Нужно указать корректный IPv4-адрес телевизора.'
    exit 1
}

$serial = $tvIp + ':5555'
Write-Host ""
Write-Host "Подключение к $serial ..." -ForegroundColor Cyan
& adb connect $serial | Out-Host
$state = (& adb -s $serial get-state 2>$null | Select-Object -Last 1)
if ($null -eq $state -or $state.ToString().Trim() -ne 'device') {
    Write-Error 'ADB не подключён или устройство не авторизовано. Проверьте сеть и подтвердите запрос на телевизоре.'
    exit 2
}

Write-Host ""
Write-Host "=== Устройство ===" -ForegroundColor Cyan
& adb -s $serial shell getprop ro.product.model
& adb -s $serial shell getprop ro.build.version.release
& adb -s $serial shell getprop ro.build.fingerprint

Write-Host ""
Write-Host "=== Текущий HOME-компонент ===" -ForegroundColor Cyan
& adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

Write-Host ""
Write-Host "=== Активное приложение ===" -ForegroundColor Cyan
& adb -s $serial shell dumpsys activity activities | Select-String -Pattern 'mResumedActivity'

Write-Host ""
Write-Host "=== Специальные возможности ===" -ForegroundColor Cyan
& adb -s $serial shell settings get secure enabled_accessibility_services
& adb -s $serial shell settings get secure accessibility_enabled

Write-Host ""
Write-Host "=== Связанные пакеты (только чтение) ===" -ForegroundColor Cyan
& adb -s $serial shell pm list packages | Select-String -Pattern 'gathin|yandex|cvte'

Write-Host ""
Write-Host "Готово. Скрипт только читает диагностические данные; он не меняет настройки телевизора." -ForegroundColor Green
