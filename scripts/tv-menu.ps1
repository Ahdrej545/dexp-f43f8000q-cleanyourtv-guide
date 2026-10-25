# Interactive ADB menu for DEXP F43F8000Q-G / CleanYourTV.
# Requires Android Platform Tools (adb) and an enabled, authorized ADB connection.
# This script does not disable or uninstall system packages.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Launcher = "com.gathin.tvhome/.MainActivity"
# Optional apps only. The stock Yandex launcher is intentionally NOT in this list.
$StopList = @(
    "ru.vk.store.tv",
    "com.yandex.browser.tv",
    "com.swiftsoft.anixartd"
)
$Desktop = [Environment]::GetFolderPath("Desktop")
$script:TvAddr = $null

function Test-Adb {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        Write-Host "adb не найден. Установите Android Platform Tools." -ForegroundColor Red
        exit 1
    }
}

function Initialize-TvAddress {
    while ($true) {
        $ip = Read-Host "IP-адрес телевизора из сетевых настроек (без :5555)"
        $parsed = $null
        $valid = [System.Net.IPAddress]::TryParse($ip, [ref]$parsed)
        if ($valid -and $parsed.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork) {
            $script:TvAddr = $ip + ":5555"
            return
        }
        Write-Host "Введите корректный IPv4-адрес." -ForegroundColor Yellow
    }
}

function Connect-Tv {
    $list = (adb devices) -join [Environment]::NewLine
    if ($list -notmatch ([regex]::Escape($script:TvAddr) + "\s+device")) {
        Write-Host "Подключаюсь к $script:TvAddr ..."
        adb connect $script:TvAddr
        Start-Sleep -Seconds 2
        $list = (adb devices) -join [Environment]::NewLine
    }
    if ($list -notmatch ([regex]::Escape($script:TvAddr) + "\s+device")) {
        Write-Host "Нет соединения. Проверьте IP, домашнюю сеть и разрешение ADB на телевизоре." -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Show-Menu {
    Clear-Host
    Write-Host "=== DEXP F43F8000Q-G / CleanYourTV ===" -ForegroundColor Cyan
    Write-Host "ADB: $script:TvAddr"
    Write-Host " 1. Подключиться и показать статус"
    Write-Host " 2. Принудительно закрыть выбранные приложения (не очистка RAM)"
    Write-Host " 3. Назначить и открыть CleanYourTV"
    Write-Host " 4. Показать сведения о памяти"
    Write-Host " 5. Сохранить скриншот на рабочий стол"
    Write-Host " 6. Показать отключённые пакеты"
    Write-Host " 7. Попробовать скопировать файлы настроек CleanYourTV"
    Write-Host " 8. Перезагрузить телевизор"
    Write-Host " 9. Сменить IP телевизора"
    Write-Host " 0. Выход"
    Write-Host ""
}

function Invoke-Choice($choice) {
    switch ($choice) {
        "1" {
            if (Connect-Tv) { adb devices }
        }
        "2" {
            Write-Host "Будут принудительно закрыты только следующие приложения:" -ForegroundColor Yellow
            $StopList | ForEach-Object { Write-Host " - $_" }
            Write-Host "Штатный лаунчер Яндекса не закрывается этим пунктом."
            $answer = Read-Host "Продолжить? (y/n)"
            if ($answer -match '^(y|yes)$' -and (Connect-Tv)) {
                foreach ($pkg in $StopList) {
                    Write-Host "Закрываю $pkg"
                    adb -s $script:TvAddr shell am force-stop $pkg
                }
                Write-Host "Готово. Это не очищает системную RAM; приложения могут запуститься снова." -ForegroundColor Green
            }
        }
        "3" {
            if (Connect-Tv) {
                adb -s $script:TvAddr shell cmd package set-home-activity --user 0 $Launcher
                adb -s $script:TvAddr shell am start -n $Launcher
            }
        }
        "4" {
            if (Connect-Tv) {
                adb -s $script:TvAddr shell cat /proc/meminfo
                Write-Host ""
                Write-Host "Сводка процесса/системы:"
                adb -s $script:TvAddr shell dumpsys meminfo | Select-String "Total RAM|Free RAM|Used RAM|Lost RAM|ZRAM"
            }
        }
        "5" {
            if (Connect-Tv) {
                $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
                $file = Join-Path $Desktop ("tv-" + $stamp + ".png")
                $cmd = 'adb -s ' + $script:TvAddr + ' exec-out screencap -p > "' + $file + '"'
                cmd.exe /d /s /c $cmd
                if (Test-Path $file) {
                    Write-Host "Скриншот сохранён: $file" -ForegroundColor Green
                    Write-Host "Проверьте изображение на Wi-Fi-имя, адреса и личные сведения перед публикацией."
                } else {
                    Write-Host "Не удалось сохранить скриншот." -ForegroundColor Yellow
                }
            }
        }
        "6" {
            if (Connect-Tv) {
                adb -s $script:TvAddr shell pm list packages -d
            }
        }
        "7" {
            if (Connect-Tv) {
                $dest = Join-Path $Desktop ("tv-launcher-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
                adb -s $script:TvAddr pull /sdcard/Android/data/com.gathin.tvhome/files $dest
                Write-Host "Если каталог существует и доступен, копия находится в: $dest" -ForegroundColor Green
                Write-Host "Успех зависит от версии приложения и разрешений Android."
            }
        }
        "8" {
            $answer = Read-Host "Перезагрузить телевизор? Это прервёт просмотр. (y/n)"
            if ($answer -match '^(y|yes)$' -and (Connect-Tv)) {
                adb -s $script:TvAddr reboot
                Write-Host "Телевизор перезагружается. ADB может появиться снова после загрузки."
            }
        }
        "9" { Initialize-TvAddress }
        "0" { exit 0 }
        default { Write-Host "Нет такого пункта." -ForegroundColor Yellow }
    }
}

Test-Adb
Initialize-TvAddress
while ($true) {
    Show-Menu
    $choice = Read-Host "Выбор"
    Invoke-Choice $choice
    Write-Host ""
    Read-Host "Нажмите Enter, чтобы вернуться в меню" | Out-Null
}
