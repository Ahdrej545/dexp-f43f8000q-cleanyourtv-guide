# Interactive ADB menu for DEXP F43F8000Q-G / CleanYourTV.
# Requires Android Platform Tools (adb) and an enabled, authorized ADB connection.
# This script does not disable or uninstall system packages.

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Launcher = "com.gathin.tvhome/.MainActivity"
$StopList = @("ru.vk.store.tv", "com.yandex.browser.tv", "com.swiftsoft.anixartd")
$Desktop = [Environment]::GetFolderPath("Desktop")
if ([string]::IsNullOrWhiteSpace($Desktop)) { $Desktop = $HOME }
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
        Write-Host "Введите корректный IPv4-адрес телевизора." -ForegroundColor Yellow
    }
}
function Get-TvState {
    $state = (& adb -s $script:TvAddr get-state 2>$null | Select-Object -Last 1)
    if ($null -eq $state) { return "" }
    return $state.ToString().Trim()
}
function Connect-Tv {
    if ((Get-TvState) -ne "device") {
        Write-Host "Подключаюсь к $script:TvAddr ..."
        & adb connect $script:TvAddr
        Start-Sleep -Seconds 2
    }
    if ((Get-TvState) -ne "device") {
        Write-Host "Нет авторизованного соединения. Проверьте IP, сеть, ADB и подтверждение на телевизоре." -ForegroundColor Yellow
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
            if (Connect-Tv) { & adb devices }
        }
        "2" {
            Write-Host "Будут принудительно закрыты только следующие приложения:" -ForegroundColor Yellow
            $StopList | ForEach-Object { Write-Host " - $_" }
            Write-Host "Штатный лаунчер Яндекса не закрывается этим пунктом."
            $answer = Read-Host "Продолжить? (y/n или д/да)"
            if ($answer -match '^(y|yes|д|да)$' -and (Connect-Tv)) {
                foreach ($pkg in $StopList) {
                    Write-Host "Закрываю $pkg"
                    & adb -s $script:TvAddr shell am force-stop $pkg
                }
                Write-Host "Готово. Это не очищает системную RAM; приложения могут запуститься снова." -ForegroundColor Green
            }
        }
        "3" {
            if (Connect-Tv) {
                & adb -s $script:TvAddr shell cmd package set-home-activity --user 0 $Launcher
                & adb -s $script:TvAddr shell am start -n $Launcher
            }
        }
        "4" {
            if (Connect-Tv) {
                & adb -s $script:TvAddr shell cat /proc/meminfo
                Write-Host ""
                Write-Host "Сводка dumpsys meminfo:"
                & adb -s $script:TvAddr shell dumpsys meminfo | Select-String "Total RAM|Free RAM|Used RAM|Lost RAM|ZRAM"
            }
        }
        "5" {
            if (Connect-Tv) {
                $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
                $file = Join-Path $Desktop ("tv-" + $stamp + ".png")
                $adbPath = (Get-Command adb -ErrorAction Stop).Source
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $adbPath
                $psi.Arguments = '-s "' + $script:TvAddr + '" exec-out screencap -p'
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $process = $null
                $stream = $null
                $stderr = ""
                $exitCode = -1
                try {
                    # Open the target before starting adb so a path/permission error cannot leave
                    # a child process blocked while writing to an unread pipe.
                    $stream = [System.IO.File]::Open($file, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
                    $process = [System.Diagnostics.Process]::Start($psi)
                    $process.StandardOutput.BaseStream.CopyTo($stream)
                    $stream.Dispose()
                    $stream = $null
                    $stderr = $process.StandardError.ReadToEnd()
                    $process.WaitForExit()
                    $exitCode = $process.ExitCode
                } catch {
                    Write-Host ("Ошибка захвата скриншота: " + $_.Exception.Message) -ForegroundColor Yellow
                    if ($null -ne $process -and -not $process.HasExited) {
                        $process.Kill()
                        $process.WaitForExit()
                    }
                } finally {
                    if ($null -ne $stream) { $stream.Dispose() }
                    if ($null -ne $process) { $process.Dispose() }
                }
                if ($exitCode -eq 0 -and (Test-Path -LiteralPath $file) -and (Get-Item -LiteralPath $file).Length -gt 0) {
                    Write-Host "Скриншот сохранён: $file" -ForegroundColor Green
                    Write-Host "Проверьте изображение на Wi-Fi-имя, адреса и личные сведения перед публикацией."
                } else {
                    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Host $stderr -ForegroundColor DarkYellow }
                    Write-Host "Не удалось сохранить скриншот; пустой или неполный файл удалён." -ForegroundColor Yellow
                }
            }
        }
        "6" {
            if (Connect-Tv) { & adb -s $script:TvAddr shell pm list packages -d }
        }
        "7" {
            if (Connect-Tv) {
                $dest = Join-Path $Desktop ("tv-launcher-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
                & adb -s $script:TvAddr pull /sdcard/Android/data/com.gathin.tvhome/files $dest
                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Команда копирования завершилась. Проверьте файлы в: $dest" -ForegroundColor Green
                } else {
                    Write-Host "Не удалось скопировать каталог. Android может скрывать его или каталог может отсутствовать." -ForegroundColor Yellow
                }
            }
        }
        "8" {
            $answer = Read-Host "Перезагрузить телевизор? Это прервёт просмотр. (y/n или д/да)"
            if ($answer -match '^(y|yes|д|да)$' -and (Connect-Tv)) {
                & adb -s $script:TvAddr reboot
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
