#!/usr/bin/env bash
set -eo pipefail

pn=$(basename $0)
CONFIG_DIR=~/.config/password-manager
TOTP_DIR="$CONFIG_DIR/2fa"
PASS_DIR="$CONFIG_DIR/passwords"

function init() {
    mkdir -p "$TOTP_DIR" "$PASS_DIR" || {
        echo "Не удалось создать директории" >&2
        exit 6
    }
    chmod 700 "$CONFIG_DIR" "$TOTP_DIR" "$PASS_DIR"
    
    local deps=("gpg")
    [[ $1 == "totp" ]] && deps+=("oathtool")
    
    for dep in "${deps[@]}"; do
        if ! hash "$dep" 2>/dev/null; then
            echo "Требуется установить: $dep" >&2
            exit 1
        fi
    done
}

list_files() {
    find "$1" -maxdepth 1 -type f -exec basename {} \; 2>/dev/null
}

add_secret() {
    local store_type=$1 identifier secret passphrase
    local store_dir=${store_type}_DIR
    store_dir="${!store_dir}"
    
    [[ -n $2 ]] && identifier=$2 || read -rp "Введите идентификатор: " identifier
    [[ -n $3 ]] && { secret="$3"; } || {
        echo -n "Введите $store_type секрет: "
        read -rs secret
        echo
    }
    
    # Определение пароля (приоритет: аргумент > переменная среды > запрос)
    if [[ -n $4 ]]; then
        passphrase="$4"
    elif [[ -n "$PASSMANPASS" ]]; then
        passphrase="$PASSMANPASS"
    else
        passphrase=""
    fi

    if [[ -f "$store_dir/$identifier" ]]; then
        [[ -z "$3" ]] && {
            read -rp "Запись '$identifier' существует. Перезаписать? [y/N] " answer
            [[ ${answer,,} != "y" ]] && exit 0
        }
    fi

    if [[ $store_type == "PASS" && -z "$3" ]]; then
        while true; do
            echo -n "Повторите пароль: "
            read -rs secret_verify
            echo
            [[ "$secret" == "$secret_verify" ]] && break
            echo "Пароли не совпадают!" >&2
        done
    fi

    if [[ -n "$passphrase" ]]; then
        echo -n "$secret" | gpg --batch --yes --passphrase "$passphrase" --quiet --symmetric --output "$store_dir/$identifier"
    else
        echo -n "$secret" | gpg --yes --quiet --symmetric --output "$store_dir/$identifier"
    fi || {
        echo "Ошибка шифрования!" >&2
        exit 5
    }
    
    echo "Секрет для '$identifier' успешно сохранён"
}

get_secret() {
    local store_type=$1 passphrase
    local store_dir=${store_type}_DIR
    store_dir="${!store_dir}"
    
    [[ -n $2 ]] && identifier=$2 || read -rp "Введите идентификатор: " identifier
    
    # Определение пароля (приоритет: аргумент > переменная среды > запрос)
    if [[ -n $3 ]]; then
        passphrase="$3"
    else
        passphrase="$PASSMANPASS"
    fi

    if [[ -n "$passphrase" ]]; then
        secret=$(gpg --batch --passphrase "$passphrase" --quiet < "$store_dir/$identifier" 2>/dev/null)
    else
        secret=$(gpg --quiet < "$store_dir/$identifier" 2>/dev/null)
    fi || {
        echo "'$identifier' не удалось расшифровать" >&2
        exit 3
    }
    
    if [[ $store_type == "TOTP" ]]; then
        token=$(oathtool --base32 --totp "$secret") || {
            echo "Ошибка генерации токена" >&2
            exit 4
        }
        if clipboard_copy "$token"; then
            echo "Токен скопирован в буфер"
        else
            echo "Токен: $token"
        fi
    else
        if clipboard_copy "$secret"; then
            echo "Пароль скопирован в буфер"
        else
            echo "Пароль: $secret"
        fi
    fi
}

clipboard_copy() {
    local text="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        if hash pbcopy 2>/dev/null; then
            echo -n "$text" | pbcopy
            return 0
        fi
    else
        if hash xclip 2>/dev/null && [[ -n "$DISPLAY" ]]; then
            echo -n "$text" | xclip -selection clipboard
            return 0
        elif hash wl-copy 2>/dev/null && [[ -n "$WAYLAND_DISPLAY" ]]; then
            echo -n "$text" | wl-copy
            return 0
        fi
    fi
    echo "$text"
    return 1
}

create_backup() {
    local backup_path="$1"
    [[ -z "$backup_path" ]] && {
        echo "Не указан путь для резервной копии" >&2
        exit 7
    }
    
    mkdir -p "$backup_path" || {
        echo "Не удалось создать директорию для бэкапа" >&2
        exit 8
    }
    
    local backup_file="$backup_path/passman_$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    tar -czf "$backup_file" -C "$CONFIG_DIR" 2fa passwords || {
        echo "Ошибка создания бэкапа" >&2
        exit 9
    }
    
    echo "Резервная копия создана: $backup_file"
}

generate_completion() {
    cat <<EOF
_pmcompletion() {
    local cur prev words cword
    COMPREPLY=()
    cur="\${COMP_WORDS[COMP_CWORD]}"
    prev="\${COMP_WORDS[COMP_CWORD-1]}"
    local CONFIG_DIR="$CONFIG_DIR"
    
    case "\$prev" in
        --add-totp|--totp)
            COMPREPLY=(\$(compgen -W "\$(find "\$CONFIG_DIR/2fa" -maxdepth 1 -type f -exec basename {} \; 2>/dev/null)" -- "\$cur"))
            ;;
        --add-pass|--pass)
            COMPREPLY=(\$(compgen -W "\$(find "\$CONFIG_DIR/passwords" -maxdepth 1 -type f -exec basename {} \; 2>/dev/null)" -- "\$cur"))
            ;;
        --backup)
            COMPREPLY=(\$(compgen -d -- "\$cur"))
            ;;
        *)
            if [[ \$COMP_CWORD -eq 1 ]]; then
                COMPREPLY=(\$(compgen -W "--add-totp --totp --add-pass --pass --list-totp --list-pass --backup --help --completion" -- "\$cur"))
            fi
            ;;
    esac
}
complete -F _pmcompletion $pn
EOF
}

generate_password() {
    local length=${1:-16}
    cat /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*()' | head -c "$length"
    echo
}

help() {
    cat <<EOF
Password Manager v0.9

Команды:
  --add-totp [ID] [СЕКРЕТ] [ПАРОЛЬ]              Добавить TOTP
  --totp [ID] [ПАРОЛЬ]                           Получить TOTP токен
  --add-pass [ID] [ПАРОЛЬ | --gen num] [КЛЮЧ]    Добавить пароль (num = количество символов для генерации)
  --pass [ID] [КЛЮЧ]                             Получить пароль
  --list-totp                                    Список TOTP записей
  --list-pass                                    Список паролей
  --backup [ПУТЬ]                                Создать резервную копию
  --completion                                   Bash completion: source <($pn --completion)
  --help                                         Справка

Переменные среды:
  PASSMANPASS    Пароль по умолчанию для GPG (если не указан в командной строке)

Примеры:
  # Использование переменной среды
  export PASSMANPASS="mySecurePassword"
  $pn --add-totp myservice "BASE32SECRET"
  $pn --totp myservice

  # Переопределение пароля через аргумент
  $pn --add-pass email "myPassword" "storePassword"

  $pn --add-pass email --gen 20 
  $pn --add-pass email --gen 20 storePassword
EOF
}

case $1 in
    --add-totp)      init "totp"; add_secret "TOTP" "$2" "$3" "$4" ;;
    --totp)          init "totp"; get_secret "TOTP" "$2" "$3" ;;
    --add-pass)      init
        if [[ $3 == "--gen" ]]; then
            secret=$(generate_password "$4")
	    echo "$2" "$4"
            add_secret "PASS" "$2" "$secret" "$5"
        else
            add_secret "PASS" "$2" "$3" "$4"
        fi
        ;;
    --pass)          init; get_secret "PASS" "$2" "$3" ;;
    --list-totp)     list_files "$TOTP_DIR" ;;
    --list-pass)     list_files "$PASS_DIR" ;;
    --backup)        create_backup "$2" ;;
    --completion)    generate_completion ;;
    --gen)           generate_password "$2" ;;
    --help|*)        help; exit 0 ;;
esac
