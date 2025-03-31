# Password Manager (pm)

Утилита для безопасного хранения паролей и TOTP-токенов с использованием GPG-шифрования.

## Особенности

- Шифрование данных с помощью GPG
- Генерация TOTP-токенов через oathtool
- Копирование паролей и TOTP-токенов в буфер обмена без отображения
- Работа в интерактивном и не интерактивном режимах
- Поддержка Linux/macOS

## Установка зависимостей

### Для всех систем:
```bash
git clone https://github.com/yourrepo/password-manager.git
cd password-manager
sudo cp pm /usr/local/bin/
```

Установка GPG и oathtool:



| Система | Команды |
| ------ | ------ |
| macOS | `brew install gnupg oath-toolkit` |
| Debian | `sudo apt update && sudo apt install gnupg oathtool` |
| RHEL | `sudo dnf install gnupg2 oath-toolkit` или `sudo yum install gnupg2 oath-toolkit` |
	
## Настройка

### Инициализация хранилища:

```bash
pm --add-pass test
```

### Настройка автодополнения для bash:

```bash
Copy
echo 'source <(pm --completion)' >> ~/.bashrc
source ~/.bashrc
```

## Использование

### Основные команды:

```bash
# Добавление пароля
pm --add-pass [ИДЕНТИФИКАТОР]

# Получение пароля
pm --pass [ИДЕНТИФИКАТОР]

# Добавление TOTP
pm --add-totp [ИДЕНТИФИКАТОР]

# Генерация TOTP-токена
pm --totp [ИДЕНТИФИКАТОР]

# Резервное копирование
pm --backup [ПУТЬ]

# Список записей
pm --list-pass
pm --list-totp
```

### Использование переменных среды:

```bash
# Для автоматизации (пароль будет использован если не указан в CLI)
export PASSMANPASS="ваш_пароль"
pm --add-totp myservice serviceSuperSecret
```

## Резервное копирование и восстановление

### Создание резервной копии:

```bash
pm --backup ~/backups
```

### Восстановление из резервной копии:

```bash
tar -xzf ~/backups/passman_*.tar.gz -C ~/.config/
```

## Внимание!

🛡 Защитите директорию конфигурации:

```bash
chmod -R 700 ~/.config/password-manager
```

## Примеры

## Добавление учетной записи Google:

```bash
pm --add-totp google "BASE32SECRETKEY"
pm --totp google
```

## Генерация сложного пароля:

```bash
pm --add-pass mysite --gen 20
```

## Лицензия

MIT License

