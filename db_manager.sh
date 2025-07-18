#!/usr/bin/env bash

# Единый интерактивный скрипт для управления базой данных
# Объединяет функциональность create_db_and_user.sh, db_backup.sh, db_restore.sh, db_patch.sh

# Цвета для вывода
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Глобальная переменная для текущего языка
CURRENT_LANG=""

# Функция автоопределения языка
detect_language() {
    # Проверяем переменные среды для определения языка
    local lang_env=""

    # Приоритет переменных: LANGUAGE > LC_ALL > LC_MESSAGES > LANG
    if [ -n "$LANGUAGE" ]; then
        lang_env="$LANGUAGE"
    elif [ -n "$LC_ALL" ]; then
        lang_env="$LC_ALL"
    elif [ -n "$LC_MESSAGES" ]; then
        lang_env="$LC_MESSAGES"
    elif [ -n "$LANG" ]; then
        lang_env="$LANG"
    fi

    # Извлекаем код языка (первые 2 символа)
    if [ -n "$lang_env" ]; then
        local lang_code="${lang_env:0:2}"
        case "$lang_code" in
            "ru"|"be"|"uk") # Русский, белорусский, украинский
                echo "ru"
                return 0
                ;;
            "en") # Английский
                echo "en"
                return 0
                ;;
            "")
                # Не определен - возвращаем пустую строку
                echo ""
                return 0
                ;;
            *)
                # Неизвестный язык - возвращаем пустую строку для интерактивного выбора
                echo ""
                return 0
                ;;
        esac
    fi

    # Если ничего не определилось - возвращаем пустую строку
    echo ""
}

# Функция получения доступных языков из locales/
get_available_languages() {
    local lang_codes=()

    for locale_file in locales/*.sh; do
        if [ -f "$locale_file" ]; then
            local lang_code=$(basename "$locale_file" .sh)
            lang_codes+=("$lang_code")
        fi
    done

    # Возвращаем массивы через глобальные переменные
    AVAILABLE_LANG_CODES=("${lang_codes[@]}")
    AVAILABLE_LANG_NAMES=("${lang_codes[@]}")  # Используем те же коды для отображения
}

# Функция показа меню выбора языка
show_language_menu() {
    local selected="$1"
    clear >&2
    echo "Choose language" >&2
    echo "Use arrows ↑/↓ to navigate, Enter to select" >&2
    echo >&2

    for i in "${!AVAILABLE_LANG_NAMES[@]}"; do
        if [ $i -eq $selected ]; then
            echo -e "${BLUE}► ${AVAILABLE_LANG_NAMES[$i]}${RESET}" >&2
        else
            echo "  ${AVAILABLE_LANG_NAMES[$i]}" >&2
        fi
    done
}

# Функция интерактивного выбора языка
select_language_interactive() {
    # Получаем доступные языки
    get_available_languages

    local selected=0
    local max_options=$((${#AVAILABLE_LANG_CODES[@]} - 1))

    while true; do
        show_language_menu $selected

        local key
        key=$(get_char)

        # Обработка escape-последовательностей для стрелок
        if [ "$key" = $'\033' ]; then
            key=$(get_char)
            if [ "$key" = "[" ]; then
                key=$(get_char)
                case "$key" in
                    "A") # Стрелка вверх
                        if [ $selected -gt 0 ]; then
                            selected=$((selected - 1))
                        fi
                        ;;
                    "B") # Стрелка вниз
                        if [ $selected -lt $max_options ]; then
                            selected=$((selected + 1))
                        fi
                        ;;
                esac
            fi
        elif [ "$key" = "" ] || [ "$key" = $'\n' ] || [ "$key" = $'\r' ]; then
            # Enter нажат - возвращаем код выбранного языка
            echo "${AVAILABLE_LANG_CODES[$selected]}"
            return 0
        elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            # Выход с дефолтным языком
            echo "en"
            return 0
        fi
    done
}

# Функция загрузки переводов
load_translations() {
    local lang="$1"
    local locale_file="locales/${lang}.sh"

    if [ -f "$locale_file" ]; then
        source "$locale_file"
        CURRENT_LANG="$lang"
        return 0
    else
        # Fallback на английский если файл не найден
        if [ -f "locales/en.sh" ]; then
            source "locales/en.sh"
            CURRENT_LANG="en"
            return 0
        fi
        # Если и английский не найден - используем встроенные сообщения
        return 1
    fi
}

# Функция инициализации языка
init_language() {
    # Сначала пытаемся автоопределить язык
    local detected_lang=$(detect_language)

    if [ -n "$detected_lang" ] && [ -f "locales/${detected_lang}.sh" ]; then
        # Автоопределение успешно и файл существует
        load_translations "$detected_lang"
    else
        # Автоопределение не сработало - предлагаем выбрать интерактивно
        local selected_lang=$(select_language_interactive)
        load_translations "$selected_lang"
        clear
    fi
}

# Функция для получения одного символа без Enter
get_char() {
    local char
    # Используем read для получения символа
    IFS= read -r -s -n1 char 2>/dev/null
    echo "$char"
}

# Функции для вывода
function info() {
    echo -e "${GREEN}[INFO]${RESET} $1"
}

function warn() {
    echo -e "${YELLOW}[WARN]${RESET} $1"
}

function error() {
    echo -e "${RED}[ERROR]${RESET} $1"
}

function title() {
    echo -e "${BLUE}[$MSG_DB_MANAGER]${RESET} $1"
}

# Дефолтные значения
DEFAULT_DBHOST="localhost"
DEFAULT_DBPORT="3306"
DEFAULT_CHARSET="utf8mb4"
DEFAULT_COLLATION="utf8mb4_general_ci"
DEFAULT_PATHTOSAVEDB="localdb/"

# Переменные конфигурации
DBNAME=""
DBUSER=""
DBUSERPASSWORD=""
DBHOST=""
DBPORT=""
CHARSET=""
COLLATION=""
PATHTOSAVEDB=""
MYSQL_ROOT_PASSWORD=""

# Функция загрузки конфигурации
load_config() {
    # Сначала загружаем дефолтные значения из db.defaults.conf (если есть)
    if [ -f "db.defaults.conf" ]; then
        info "$MSG_LOADING_DEFAULTS"
        source db.defaults.conf
    fi

    # Затем загружаем и перезаписываем значения из db.conf (если есть)
    if [ -f "db.conf" ]; then
        info "$MSG_LOADING_CONFIG"
        # Сохраняем значения из defaults для случаев, когда в db.conf есть пустые значения
        local defaults_DBNAME="$DBNAME"
        local defaults_DBUSER="$DBUSER"
        local defaults_DBUSERPASSWORD="$DBUSERPASSWORD"
        local defaults_DBHOST="$DBHOST"
        local defaults_DBPORT="$DBPORT"
        local defaults_CHARSET="$CHARSET"
        local defaults_COLLATION="$COLLATION"
        local defaults_PATHTOSAVEDB="$PATHTOSAVEDB"
        local defaults_MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"

        source db.conf

        # Если в db.conf значение пустое, используем из defaults
        [ -z "$DBNAME" ] && DBNAME="$defaults_DBNAME"
        [ -z "$DBUSER" ] && DBUSER="$defaults_DBUSER"
        [ -z "$DBUSERPASSWORD" ] && DBUSERPASSWORD="$defaults_DBUSERPASSWORD"
        [ -z "$DBHOST" ] && DBHOST="$defaults_DBHOST"
        [ -z "$DBPORT" ] && DBPORT="$defaults_DBPORT"
        [ -z "$CHARSET" ] && CHARSET="$defaults_CHARSET"
        [ -z "$COLLATION" ] && COLLATION="$defaults_COLLATION"
        [ -z "$PATHTOSAVEDB" ] && PATHTOSAVEDB="$defaults_PATHTOSAVEDB"
        [ -z "$MYSQL_ROOT_PASSWORD" ] && MYSQL_ROOT_PASSWORD="$defaults_MYSQL_ROOT_PASSWORD"
    elif [ ! -f "db.defaults.conf" ]; then
        warn "$MSG_NO_CONFIG_FILES"
    fi

    # Устанавливаем встроенные дефолтные значения для переменных, которые все еще пустые
    [ -z "$DBHOST" ] && DBHOST="$DEFAULT_DBHOST"
    [ -z "$DBPORT" ] && DBPORT="$DEFAULT_DBPORT"
    [ -z "$CHARSET" ] && CHARSET="$DEFAULT_CHARSET"
    [ -z "$COLLATION" ] && COLLATION="$DEFAULT_COLLATION"
    [ -z "$PATHTOSAVEDB" ] && PATHTOSAVEDB="$DEFAULT_PATHTOSAVEDB"
}

# Функция выполнения MySQL команд с root правами
mysql_root_exec() {
    local sql_command="$1"
    if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
        # Используем пароль из конфигурации
        mysql -u root -p"$MYSQL_ROOT_PASSWORD" -h "$DBHOST" -P "$DBPORT" -Bse "$sql_command"
    else
        # Запрашиваем пароль
        mysql -u root -p -h "$DBHOST" -P "$DBPORT" -Bse "$sql_command"
    fi
}

# Функция сохранения конфигурации
save_config() {
    cat > db.conf << EOF
#example: sitename
DBNAME="$DBNAME"
#example: sitename
DBUSER="$DBUSER"
#example: dh39ndYvnMk1K9
DBUSERPASSWORD="$DBUSERPASSWORD"
DBHOST="$DBHOST"
DBPORT="$DBPORT"
CHARSET="$CHARSET"
COLLATION="$COLLATION"
PATHTOSAVEDB="$PATHTOSAVEDB"
#MySQL root password (optional, if empty - will prompt for password)
MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD"
EOF
    info "$MSG_CONFIG_SAVED"
}

# Функция интерактивного ввода
read_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        [ -z "$input" ] && input="$default"
    else
        read -p "$prompt: " input
    fi

    eval "$var_name=\"$input\""
}

# Функция создания только БД
create_database_only() {
    title "$MSG_CREATING_DB"

    load_config

    # Интерактивный ввод параметров
    read_with_default "$MSG_DB_NAME_PARAM" "$DBNAME" "DBNAME"
    read_with_default "$MSG_DB_HOST_PARAM" "$DBHOST" "DBHOST"
    read_with_default "$MSG_DB_PORT_PARAM" "$DBPORT" "DBPORT"
    read_with_default "$MSG_DB_CHARSET_PARAM" "$CHARSET" "CHARSET"
    read_with_default "$MSG_DB_COLLATION_PARAM" "$COLLATION" "COLLATION"

    echo
    info "$MSG_CREATE_DB_PARAMS"
    echo "  $MSG_DATABASE_LABEL: $DBNAME"
    echo "  $MSG_HOST_LABEL: $DBHOST:$DBPORT"
    echo "  $MSG_CHARSET_LABEL: $CHARSET"
    echo "  $MSG_COLLATION_LABEL: $COLLATION"
    echo

    read -p "$MSG_SAVE_CONFIG_PROMPT (y/N): " save_choice
    if [[ "$save_choice" =~ ^[Yy]$ ]]; then
        save_config
    fi

    echo

    # Проверяем существование БД
    info "$MSG_CHECKING_DB_EXISTS"

    DB_EXISTS=$(mysql_root_exec "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DBNAME';" 2>/dev/null)

    if [ -n "$DB_EXISTS" ]; then
        echo
        warn "$MSG_WARNING_DB_EXISTS"
        echo "  ✓ $MSG_DB_EXISTS '$DBNAME' $MSG_ALREADY_EXISTS"
        echo
        echo "$MSG_CONTINUE_DB_RISKS"
        echo "  $MSG_RISK_DB_ERRORS"
        echo

        read -p "$MSG_CONTINUE_CREATE_DB (y/N): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            info "$MSG_CREATE_CANCELLED"
            return 0
        fi
        echo
    fi

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        info "$MSG_CREATING_DB_WITH_ROOT"
    else
        info "$MSG_CREATING_DB_WITH_SAVED"
    fi

    mysql_root_exec "CREATE DATABASE IF NOT EXISTS \`$DBNAME\` CHARACTER SET $CHARSET COLLATE $COLLATION;"

    if [ $? -eq 0 ]; then
        info "$MSG_DB_CREATED"
    else
        error "$MSG_CREATE_DB_ERROR"
        exit 1
    fi
}

# Функция создания пользователя с правами доступа к БД
create_user_only() {
    title "$MSG_CREATING_USER"

    load_config

    # Интерактивный ввод параметров
    read_with_default "$MSG_DB_USER_PARAM" "$DBUSER" "DBUSER"
    read_with_default "$MSG_DB_NAME_PARAM" "$DBNAME" "DBNAME"
    read_with_default "$MSG_DB_PASSWORD_PARAM" "$DBUSERPASSWORD" "DBUSERPASSWORD"
    read_with_default "$MSG_DB_HOST_PARAM" "$DBHOST" "DBHOST"
    read_with_default "$MSG_DB_PORT_PARAM" "$DBPORT" "DBPORT"

    echo
    info "$MSG_CREATE_USER_PARAMS"
    echo "  $MSG_USER_LABEL: $DBUSER"
    echo "  $MSG_DATABASE_LABEL: $DBNAME"
    echo "  $MSG_HOST_LABEL: $DBHOST:$DBPORT"
    echo

    read -p "$MSG_SAVE_CONFIG_PROMPT (y/N): " save_choice
    if [[ "$save_choice" =~ ^[Yy]$ ]]; then
        save_config
    fi

    echo

    # Проверяем существование пользователя и БД
    info "$MSG_CHECKING_USER_DB_EXISTS"

    DB_EXISTS=$(mysql_root_exec "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DBNAME';" 2>/dev/null)
    USER_EXISTS=$(mysql_root_exec "SELECT User FROM mysql.user WHERE User='$DBUSER' AND Host='$DBHOST';" 2>/dev/null)

    if [ -z "$DB_EXISTS" ]; then
        error "$MSG_DB_NOT_EXISTS_FOR_USER '$DBNAME'"
        echo "$MSG_CREATE_DB_FIRST"
        return 1
    fi

    if [ -n "$USER_EXISTS" ]; then
        echo
        warn "$MSG_WARNING_USER_EXISTS"
        echo "  ✓ $MSG_USER_EXISTS '$DBUSER'@'$DBHOST' $MSG_ALREADY_EXISTS"
        echo
        echo "$MSG_CONTINUE_USER_RISKS"
        echo "  $MSG_RISK_USER_ERRORS"
        echo "  $MSG_RISK_USER_OVERWRITE"
        echo

        read -p "$MSG_CONTINUE_CREATE_USER (y/N): " continue_choice
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            info "$MSG_CREATE_CANCELLED"
            return 0
        fi
        echo
    fi

    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        info "$MSG_CREATING_USER_WITH_ROOT"
    else
        info "$MSG_CREATING_USER_WITH_SAVED"
    fi

    mysql_root_exec "CREATE USER IF NOT EXISTS '$DBUSER'@'$DBHOST' IDENTIFIED BY '$DBUSERPASSWORD';
GRANT USAGE ON *.* TO '$DBUSER'@'$DBHOST' IDENTIFIED BY '$DBUSERPASSWORD' REQUIRE NONE WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0;
GRANT ALL PRIVILEGES ON \`$DBNAME\`.* TO '$DBUSER'@'$DBHOST' WITH GRANT OPTION;
FLUSH PRIVILEGES;"

    if [ $? -eq 0 ]; then
        info "$MSG_USER_CREATED"
    else
        error "$MSG_CREATE_USER_ERROR"
        exit 1
    fi
}

# Функция создания бэкапа
backup_database() {
    title "$MSG_DB_BACKUP"

    load_config

    # Проверяем наличие обязательных параметров
    if [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$DBUSERPASSWORD" ]; then
        error "$MSG_NO_CONNECTION_PARAMS"
        exit 1
    fi

    read_with_default "$MSG_BACKUP_DIR_PARAM" "$PATHTOSAVEDB" "PATHTOSAVEDB"

    # Создаем каталог если не существует
    [ ! -d "$PATHTOSAVEDB" ] && mkdir -p "$PATHTOSAVEDB"

    MYSQLDUMPBIN="$(which mysqldump)"
    if [ -z "$MYSQLDUMPBIN" ]; then
        error "$MSG_MYSQLDUMP_NOT_FOUND"
        exit 1
    fi

    NOW=$(date +"%y%m%d%H%M")
    BACKUP_FILE="${PATHTOSAVEDB}actual_db_${NOW}.sql"
    CURRENT_FILE="${PATHTOSAVEDB}current_db.sql"

    info "$MSG_CREATING_BACKUP $BACKUP_FILE"

    $MYSQLDUMPBIN --no-tablespaces --add-drop-table --allow-keywords --create-options --skip-comments -e -q -c -u "$DBUSER" -p"$DBUSERPASSWORD" -h "$DBHOST" -P "$DBPORT" "$DBNAME" > "$BACKUP_FILE"

    if [ $? -eq 0 ]; then
        cp "$BACKUP_FILE" "$CURRENT_FILE"
        info "$MSG_BACKUP_CREATED $BACKUP_FILE"
        info "$MSG_CURRENT_BACKUP_COPIED $CURRENT_FILE"
    else
        error "$MSG_BACKUP_ERROR"
        exit 1
    fi
}

# Функция восстановления БД
restore_database() {
    title "$MSG_DB_RESTORE"

    load_config

    # Проверяем наличие обязательных параметров
    if [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$DBUSERPASSWORD" ]; then
        error "$MSG_NO_CONNECTION_PARAMS"
        exit 1
    fi

    read_with_default "$MSG_BACKUP_DIR_RESTORE" "$PATHTOSAVEDB" "PATHTOSAVEDB"

    # Предлагаем выбрать файл для восстановления
    echo "$MSG_AVAILABLE_BACKUPS"
    ls -la "${PATHTOSAVEDB}"*.sql 2>/dev/null | nl
    echo

    DEFAULT_RESTORE_FILE="${PATHTOSAVEDB}current_db.sql"
    
    # Используем интерактивный ввод с автодополнением для пути к файлу
    if [ -t 0 ]; then
        # Включаем автодополнение для файлов
        set +H  # Отключаем history expansion
        read -e -p "$MSG_BACKUP_FILE_PATH [$DEFAULT_RESTORE_FILE]: " RESTORE_FILE
        set -H  # Включаем обратно
        # Если пользователь не ввел ничего, используем дефолтное значение
        [ -z "$RESTORE_FILE" ] && RESTORE_FILE="$DEFAULT_RESTORE_FILE"
    else
        # Fallback для неинтерактивного режима
        read_with_default "$MSG_BACKUP_FILE_PATH" "$DEFAULT_RESTORE_FILE" "RESTORE_FILE"
    fi

    if [ ! -f "$RESTORE_FILE" ]; then
        error "$MSG_BACKUP_NOT_FOUND $RESTORE_FILE"
        exit 1
    fi

    info "$MSG_RESTORING_FROM $RESTORE_FILE"

    mysql -u "$DBUSER" -p"$DBUSERPASSWORD" -h "$DBHOST" -P "$DBPORT" "$DBNAME" < "$RESTORE_FILE"

    if [ $? -eq 0 ]; then
        info "$MSG_DB_RESTORED"
    else
        error "$MSG_RESTORE_ERROR"
        exit 1
    fi
}

# Функция применения патча
patch_database() {
    title "$MSG_APPLYING_PATCH"

    load_config

    # Проверяем наличие обязательных параметров
    if [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$DBUSERPASSWORD" ]; then
        error "$MSG_NO_CONNECTION_PARAMS"
        exit 1
    fi

    local sqlfile="$1"

    if [ -n "$sqlfile" ]; then
        if [ ! -f "$sqlfile" ]; then
            error "$MSG_FILE_NOT_FOUND $sqlfile"
            exit 1
        fi
        info "$MSG_EXECUTING_SQL $sqlfile"
        mysql -u "$DBUSER" -p"$DBUSERPASSWORD" -h "$DBHOST" -P "$DBPORT" "$DBNAME" < "$sqlfile"
    else
        if [ -t 0 ]; then
            # Включаем автодополнение для файлов
            set +H  # Отключаем history expansion
            read -e -p "$MSG_SQL_FILE_PATH " sqlfile
            set -H  # Включаем обратно
            if [ ! -f "$sqlfile" ]; then
                error "$MSG_FILE_NOT_FOUND $sqlfile"
                exit 1
            fi
            mysql -u "$DBUSER" -p"$DBUSERPASSWORD" -h "$DBHOST" -P "$DBPORT" "$DBNAME" < "$sqlfile"
        else
            info "$MSG_READING_FROM_STDIN"
            mysql -u "$DBUSER" -p"$DBUSERPASSWORD" -h "$DBHOST" -P "$DBPORT" "$DBNAME"
        fi
    fi

    if [ $? -eq 0 ]; then
        info "$MSG_PATCH_APPLIED"
    else
        error "$MSG_PATCH_ERROR"
        exit 1
    fi
}

# Функция подключения к БД
connect_database() {
    title "$MSG_DB_CONNECTION"

    load_config

    # Проверяем наличие обязательных параметров
    if [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$DBUSERPASSWORD" ]; then
        error "$MSG_NO_CONNECTION_PARAMS"
        exit 1
    fi

    info "$MSG_CONNECTION_INFO"
    echo "  $MSG_USER_LABEL: $DBUSER"
    echo "  $MSG_DATABASE_LABEL: $DBNAME"
    echo "  $MSG_HOST_LABEL: $DBHOST:$DBPORT"
    echo

    info "$MSG_STARTING_SESSION"
    echo "$MSG_EXIT_INSTRUCTIONS"
    echo

    # Подключаемся к MySQL в интерактивном режиме
    mysql -u "$DBUSER" -p"$DBUSERPASSWORD" -h "$DBHOST" -P "$DBPORT" "$DBNAME"

    if [ $? -eq 0 ]; then
        info "$MSG_SESSION_ENDED"
    else
        error "$MSG_CONNECTION_ERROR"
        exit 1
    fi
}

# Функция удаления базы данных
drop_database() {
    title "$MSG_DROPPING_DB"

    load_config

    # Проверяем наличие обязательных параметров
    if [ -z "$DBNAME" ] || [ -z "$DBUSER" ] || [ -z "$DBUSERPASSWORD" ]; then
        error "$MSG_NO_CONNECTION_PARAMS"
        exit 1
    fi

    # Проверяем существование базы данных
    info "$MSG_CHECKING_DB_EXISTS"
    DB_EXISTS=$(mysql_root_exec "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DBNAME';" 2>/dev/null)

    if [ -z "$DB_EXISTS" ]; then
        warn "$MSG_DB_NOT_EXISTS '$DBNAME' $MSG_NOT_EXISTS"
        return 0
    fi

    echo
    warn "$MSG_WARNING_DROP_DB"
    echo "  $MSG_DATABASE_LABEL: $DBNAME"
    echo "  $MSG_HOST_LABEL: $DBHOST:$DBPORT"
    echo
    echo "$MSG_ACTION_IRREVERSIBLE"
    echo

    read -p "$MSG_CONFIRM_DROP " confirmation
    if [ "$confirmation" != "yes" ]; then
        info "$MSG_DROP_CANCELLED"
        return 0
    fi

    read -p "$MSG_REPEAT_DB_NAME " db_confirm
    if [ "$db_confirm" != "$DBNAME" ]; then
        error "$MSG_NAME_MISMATCH"
        return 1
    fi

    echo
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        info "$MSG_DROPPING_DB_ROOT"
    else
        info "$MSG_DROPPING_DB_SAVED"
    fi

    mysql_root_exec "DROP DATABASE IF EXISTS \`$DBNAME\`;"

    if [ $? -eq 0 ]; then
        info "$MSG_DB_DROPPED '$DBNAME' $MSG_SUCCESSFULLY_DROPPED"
    else
        error "$MSG_DROP_DB_ERROR"
        exit 1
    fi
}

# Функция удаления пользователя
drop_user() {
    title "$MSG_DROPPING_USER"

    load_config

    # Проверяем наличие обязательных параметров
    if [ -z "$DBUSER" ] || [ -z "$DBHOST" ]; then
        error "$MSG_NO_USER_PARAMS"
        exit 1
    fi

    # Проверяем существование пользователя
    info "$MSG_CHECKING_USER_EXISTS"
    USER_EXISTS=$(mysql_root_exec "SELECT User FROM mysql.user WHERE User='$DBUSER' AND Host='$DBHOST';" 2>/dev/null)

    if [ -z "$USER_EXISTS" ]; then
        warn "$MSG_USER_NOT_EXISTS '$DBUSER'@'$DBHOST' $MSG_NOT_EXISTS"
        return 0
    fi

    echo
    warn "$MSG_WARNING_DROP_USER"
    echo "  $MSG_USER_LABEL_DROP: $DBUSER"
    echo "  $MSG_HOST_LABEL_DROP: $DBHOST"
    echo
    echo "$MSG_ACTION_IRREVERSIBLE_USER"
    echo

    read -p "$MSG_CONFIRM_DROP " confirmation
    if [ "$confirmation" != "yes" ]; then
        info "$MSG_DROP_CANCELLED"
        return 0
    fi

    read -p "$MSG_REPEAT_USER_NAME " user_confirm
    if [ "$user_confirm" != "$DBUSER" ]; then
        error "$MSG_USER_NAME_MISMATCH"
        return 1
    fi

    echo
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        info "$MSG_DROPPING_USER_ROOT"
    else
        info "$MSG_DROPPING_USER_SAVED"
    fi

    mysql_root_exec "DROP USER IF EXISTS '$DBUSER'@'$DBHOST'; FLUSH PRIVILEGES;"

    if [ $? -eq 0 ]; then
        info "$MSG_USER_DROPPED '$DBUSER'@'$DBHOST' $MSG_SUCCESSFULLY_DROPPED_USER"
    else
        error "$MSG_DROP_USER_ERROR"
        exit 1
    fi
}

# Функция показа справки
show_help() {
    echo "$MSG_USAGE $0 $MSG_USAGE_PARAMS"
    echo
    echo "$MSG_OPTIONS"
    echo "  --create-db      $MSG_CREATE_DB_OPTION"
    echo "  --create-user    $MSG_CREATE_USER_OPTION"
    echo "  --backup         $MSG_BACKUP_OPTION"
    echo "  --restore        $MSG_RESTORE_OPTION"
    echo "  --patch $MSG_PATCH_FILE_PARAM   $MSG_PATCH_OPTION"
    echo "  --connect        $MSG_CONNECT_OPTION"
    echo "  --drop-db        $MSG_DROP_DB_OPTION"
    echo "  --drop-user      $MSG_DROP_USER_OPTION"
    echo "  --help           $MSG_HELP_OPTION"
    echo
    echo "$MSG_INTERACTIVE_MODE"
    echo "  $MSG_NAVIGATION_HELP"
    echo "  • $MSG_CREATE_DB"
    echo "  • $MSG_CREATE_USER"
    echo "  • $MSG_CREATE_BACKUP"
    echo "  • $MSG_RESTORE_DB"
    echo "  • $MSG_APPLY_PATCH"
    echo "  • $MSG_CONNECT_DB"
    echo "  • $MSG_DROP_DB"
    echo "  • $MSG_DROP_USER"
    echo
}

# Функция навигации по меню стрелками
show_menu() {
    local selected="$1"
    clear
    title "$MSG_DB_MANAGER"
    echo "$MSG_USE_ARROWS"
    echo

    local options=("$MSG_CREATE_DB" "$MSG_CREATE_USER" "$MSG_CREATE_BACKUP" "$MSG_RESTORE_DB" "$MSG_APPLY_PATCH" "$MSG_CONNECT_DB" "$MSG_DROP_DB" "$MSG_DROP_USER")

    for i in "${!options[@]}"; do
        if [ $i -eq $selected ]; then
            echo -e "${BLUE}► ${options[$i]}${RESET}"
        else
            echo "  ${options[$i]}"
        fi
    done
    echo
    echo "  $MSG_EXIT_Q"
}

# Функция интерактивного меню с навигацией стрелками
interactive_menu() {
    local selected=0
    local max_options=7

    while true; do
        show_menu $selected

        local key
        key=$(get_char)

        # Обработка escape-последовательностей для стрелок
        if [ "$key" = $'\033' ]; then
            key=$(get_char)
            if [ "$key" = "[" ]; then
                key=$(get_char)
                case "$key" in
                    "A") # Стрелка вверх
                        if [ $selected -gt 0 ]; then
                            selected=$((selected - 1))
                        fi
                        ;;
                    "B") # Стрелка вниз
                        if [ $selected -lt $max_options ]; then
                            selected=$((selected + 1))
                        fi
                        ;;
                esac
            fi
        elif [ "$key" = "" ] || [ "$key" = $'\n' ] || [ "$key" = $'\r' ]; then
            # Enter нажат
            case $selected in
                0)
                    clear
                    create_database_only
                    ;;
                1)
                    clear
                    create_user_only
                    ;;
                2)
                    clear
                    backup_database
                    ;;
                3)
                    clear
                    restore_database
                    ;;
                4)
                    clear
                    patch_database
                    ;;
                5)
                    clear
                    connect_database
                    ;;
                6)
                    clear
                    drop_database
                    ;;
                7)
                    clear
                    drop_user
                    ;;
            esac

            echo
            read -p "$MSG_PRESS_ENTER" dummy
        elif [ "$key" = "q" ] || [ "$key" = "Q" ]; then
            clear
            info "$MSG_GOODBYE"
            exit 0
        fi
    done
}

# Инициализация языка
init_language

# Основная логика
case "$1" in
    --create-db)
        create_database_only
        ;;
    --create-user)
        create_user_only
        ;;
    --backup)
        backup_database
        ;;
    --restore)
        restore_database
        ;;
    --patch)
        patch_database "$2"
        ;;
    --connect)
        connect_database
        ;;
    --drop-db)
        drop_database
        ;;
    --drop-user)
        drop_user
        ;;
    --help)
        show_help
        ;;
    "")
        interactive_menu
        ;;
    *)
        error "$MSG_UNKNOWN_OPTION: $1"
        show_help
        exit 1
        ;;
esac
