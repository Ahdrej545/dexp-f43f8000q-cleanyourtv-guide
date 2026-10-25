# Changelog

## 0.2.4 — final audit fixes

- Исправлена проверка приватных идентификаторов, которая ранее находила собственные строки валидатора.
- Проверка GitHub Actions успешно проходит после исправления.
- Скриншоты в PowerShell сохраняются напрямую в файл, без передачи пути через `cmd.exe`.
- Добавлена проверка синтаксиса PowerShell на Windows runner без выполнения скриптов.
- Обновлена версия `actions/checkout` до v7.0.1, использующей современный runtime.

## 0.2.3 — repository audit

- Hardened ADB connection checks and screenshot/backup error handling in the menu scripts.
- Added read-only connection validation to the diagnostic script.
- Made configuration-only examples independent from a separate wallpaper file.
- Added contribution guidance and static repository validation.

## 0.2.2 — screenshot and docs polish

- Добавлен скриншот домашнего экрана с замаскированным названием Wi-Fi-сети.
- Уточнено, что неоновый фон в SVG масштабируется, а для телевизоров без поддержки SVG его нужно экспортировать в PNG/JPG.

## 0.2.1 — visual assets

- Добавлена масштабируемая SVG-иллюстрация неонового фона.
- Добавлен пример конфигурации с тремя скрываемыми ярлыками.

## 0.2.0 — scripts and config examples

- Добавлены интерактивные меню ADB для Windows PowerShell и Linux.
- Убраны зашитые IP-адреса; адрес запрашивается у пользователя при запуске.
- Штатный лаунчер Яндекса не входит в список приложений, принудительно закрываемых меню.
- Добавлены подтверждение перед закрытием приложений и предупреждение, что force-stop не очищает RAM.
- Добавлены безопасный пример тёмной конфигурации и отдельный пример настроек для конкретного устройства с предупреждением.

## 0.1.0 — initial guide

- Документирован успешный пользовательский сценарий для DEXP F43F8000Q-G / Android 9.
- Добавлены безопасная проверка HOME-компонента, команды возврата и troubleshooting.
- Добавлен PowerShell-скрипт диагностики ADB только для чтения.
- APK CleanYourTV и системная прошивка в репозиторий не включены.
