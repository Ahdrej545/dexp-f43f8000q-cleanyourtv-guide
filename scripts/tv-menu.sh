#!/usr/bin/env bash
# Interactive ADB menu for DEXP F43F8000Q-G / CleanYourTV.
# Requires adb (Debian/Ubuntu/Linux Mint: sudo apt install adb).
# This script does not disable or uninstall system packages.

set -u

LAUNCHER="com.gathin.tvhome/.MainActivity"
# Optional apps only. The stock Yandex launcher is intentionally NOT in this list.
STOP_LIST=(
  "ru.vk.store.tv"
  "com.yandex.browser.tv"
  "com.swiftsoft.anixartd"
)
DESKTOP="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$HOME")"
TV_ADDR=""

if ! command -v adb >/dev/null 2>&1; then
  echo "adb не найден. Установите: sudo apt install adb"
  exit 1
fi

read_tv_ip() {
  local ip
  while true; do
    read -r -p "IP-адрес телевизора из сетевых настроек (без :5555): " ip
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] &&
       awk -F. 'NF==4 {for(i=1;i<=4;i++) if($i<0 || $i>255) exit 1; exit 0} {exit 1}' <<< "$ip"; then
      TV_ADDR="$ip:5555"
      return
    fi
    echo "Введите корректный IPv4-адрес."
  done
}

is_connected() {
  adb devices | grep -Fq "$(printf '%s\tdevice' "$TV_ADDR")"
}

connect_tv() {
  if ! is_connected; then
    echo "Подключаюсь к $TV_ADDR ..."
    adb connect "$TV_ADDR"
    sleep 2
  fi
  if ! is_connected; then
    echo "Нет соединения. Проверьте IP, сеть и разрешение ADB на телевизоре."
    return 1
  fi
  return 0
}

show_menu() {
  clear
  echo "=== DEXP F43F8000Q-G / CleanYourTV ==="
  echo "ADB: $TV_ADDR"
  echo " 1. Подключиться и показать статус"
  echo " 2. Принудительно закрыть выбранные приложения (не очистка RAM)"
  echo " 3. Назначить и открыть CleanYourTV"
  echo " 4. Показать сведения о памяти"
  echo " 5. Сохранить скриншот на рабочий стол"
  echo " 6. Показать отключённые пакеты"
  echo " 7. Попробовать скопировать файлы настроек CleanYourTV"
  echo " 8. Перезагрузить телевизор"
  echo " 9. Сменить IP телевизора"
  echo " 0. Выход"
  echo
}

while true; do
  show_menu
  read -r -p "Выбор: " choice
  case "$choice" in
    1)
      if connect_tv; then adb devices; fi
      ;;
    2)
      echo "Будут принудительно закрыты только эти приложения:"
      printf ' - %s\n' "${STOP_LIST[@]}"
      echo "Штатный лаунчер Яндекса этим пунктом не закрывается."
      read -r -p "Продолжить? (y/n) " answer
      if [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]] && connect_tv; then
        for pkg in "${STOP_LIST[@]}"; do
          echo "Закрываю $pkg"
          adb -s "$TV_ADDR" shell am force-stop "$pkg"
        done
        echo "Готово. Это не очищает системную RAM; приложения могут запуститься снова."
      fi
      ;;
    3)
      if connect_tv; then
        adb -s "$TV_ADDR" shell cmd package set-home-activity --user 0 "$LAUNCHER"
        adb -s "$TV_ADDR" shell am start -n "$LAUNCHER"
      fi
      ;;
    4)
      if connect_tv; then
        adb -s "$TV_ADDR" shell cat /proc/meminfo
        echo
        adb -s "$TV_ADDR" shell dumpsys meminfo | grep -E 'Total RAM|Free RAM|Used RAM|Lost RAM|ZRAM' || true
      fi
      ;;
    5)
      if connect_tv; then
        file="${DESKTOP}/tv-$(date +%Y%m%d-%H%M%S).png"
        if adb -s "$TV_ADDR" exec-out screencap -p > "$file"; then
          echo "Скриншот сохранён: $file"
          echo "Проверьте Wi-Fi-имя, адреса и личные сведения перед публикацией."
        else
          rm -f "$file"
          echo "Не удалось сохранить скриншот."
        fi
      fi
      ;;
    6)
      if connect_tv; then adb -s "$TV_ADDR" shell pm list packages -d; fi
      ;;
    7)
      if connect_tv; then
        dest="${DESKTOP}/tv-launcher-backup-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$dest"
        adb -s "$TV_ADDR" pull /sdcard/Android/data/com.gathin.tvhome/files "$dest"
        echo "Если каталог существует и доступен, копия находится в: $dest"
        echo "Успех зависит от версии приложения и разрешений Android."
      fi
      ;;
    8)
      read -r -p "Перезагрузить телевизор? Это прервёт просмотр. (y/n) " answer
      if [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]] && connect_tv; then
        adb -s "$TV_ADDR" reboot
        echo "Телевизор перезагружается. ADB может появиться снова после загрузки."
      fi
      ;;
    9) read_tv_ip ;;
    0) exit 0 ;;
    *) echo "Нет такого пункта." ;;
  esac
  echo
  read -r -p "Нажмите Enter, чтобы вернуться в меню " _
done
