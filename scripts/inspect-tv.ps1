# Read-only diagnostic helper for DEXP Android TV / CleanYourTV.
# Does not disable packages or modify TV settings.

$ErrorActionPreference = 'Stop'

$adb = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adb) {
    Write-Error 'adb не найден. Установи Android Platform Tools и добавь adb в PATH.'
    exit 1
}

$tvIp = Read-Host 'Введи IP-адрес телевизора из его сетевых настроек (например, 192.168.1.50)'
if ([string]::IsNullOrWhiteSpace($tvIp)) {
    Write-Error 'IP-адрес не указан.'
    exit 1
}

$serial = "${tvIp}:5555"
Write-Host "`nПодключение к $serial ..." -ForegroundColor Cyan
& adb connect $serial
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Команда adb connect вернула ошибку; проверь IP, сеть и настройки ADB.'
}

Write-Host "`n=== Устройство ===" -ForegroundColor Cyan
& adb -s $serial shell getprop ro.product.model
& adb -s $serial shell getprop ro.build.version.release
& adb -s $serial shell getprop ro.build.fingerprint

Write-Host "`n=== Текущий HOME-компонент ===" -ForegroundColor Cyan
& adb -s $serial shell cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.HOME

Write-Host "`n=== Активное приложение ===" -ForegroundColor Cyan
& adb -s $serial shell dumpsys activity activities | Select-String -Pattern 'mResumedActivity'

Write-Host "`n=== Специальные возможности ===" -ForegroundColor Cyan
& adb -s $serial shell settings get secure enabled_accessibility_services
& adb -s $serial shell settings get secure accessibility_enabled

Write-Host "`n=== Связанные пакеты (только чтение) ===" -ForegroundColor Cyan
& adb -s $serial shell pm list packages | Select-String -Pattern 'gathin|yandex|cvte'

Write-Host "`nГотово. Скрипт только читает диагностические данные; он не меняет настройки телевизора." -ForegroundColor Green
