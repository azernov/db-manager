# MySQL Database Manager

A unified interactive script for managing MySQL databases that replaces several separate scripts and provides a convenient interface for all database operations.

## Features

- ✅ **Create database** separately from user creation
- ✅ **Create user** with privileges for existing database
- ✅ **Create DB backups** with automatic naming
- ✅ **Restore DB** from backups
- ✅ **Apply SQL patches** with file autocompletion
- ✅ **Connect to DB** in interactive mode
- ✅ **Drop database** with double confirmation
- ✅ **Drop users** with safe checks
- ✅ **Arrow navigation** in interactive menu
- ✅ **Smart configuration** with priorities and fallback values
- ✅ **Multi-language support** (Russian and English) with auto-detection

## Installation and Setup

### 1. Download project

```bash
git clone https://github.com/azernov/db-manager.git
cd db-manager
```

### 2. Configuration files

The script uses a priority configuration system:

**File priority:**
1. `db.conf` - main configuration (highest priority, ignored in .gitignore)
2. `db.defaults.conf` - default values (can be in repository)
3. Built-in constants - final fallback

**Create `db.conf`:**
```bash
DBNAME="myproject"
DBUSER="myproject"
DBUSERPASSWORD=""
DBHOST="localhost"
DBPORT="3306"
CHARSET="utf8mb4"
COLLATION="utf8mb4_general_ci"
PATHTOSAVEDB="localdb/"
#MySQL root password (optional, if empty - will prompt for password)
MYSQL_ROOT_PASSWORD=""
```

### 3. Setup .gitignore

Add to your `.gitignore`:
```gitignore
# Database configuration with sensitive data
db/db.conf
```

### 4. Make script executable

```bash
chmod +x db_manager.sh
```

### 5. Language settings

The script supports **automatic language detection** based on environment variables:
- `LANGUAGE`, `LC_ALL`, `LC_MESSAGES`, `LANG` (in priority order)
- Supported languages: **Russian** (`ru`) and **English** (`en`, default)

**Available localizations:**
- `locales/ru.sh` - Russian language
- `locales/en.sh` - English language

If auto-detection doesn't work, the script will offer **interactive language selection** with arrows.

**Force language setting:**
```bash
# Run in Russian language
LANG=ru_RU.UTF-8 ./db_manager.sh

# Run in English language
LANG=en_US.UTF-8 ./db_manager.sh
```

## Usage

### Interactive mode

Run without parameters for interactive menu:
```bash
./db_manager.sh
```

**Navigation:**
- ↑/↓ - move through menu
- Enter - select item
- q - exit

### Command mode

```bash
# Create database only
./db_manager.sh --create-db

# Create user for existing database
./db_manager.sh --create-user

# Create backup
./db_manager.sh --backup

# Restore DB
./db_manager.sh --restore

# Apply SQL patch
./db_manager.sh --patch patch.sql
# Or from stdin
./db_manager.sh --patch < patch.sql

# Connect to DB
./db_manager.sh --connect

# Drop database (requires confirmation)
./db_manager.sh --drop-db

# Drop user (requires confirmation)
./db_manager.sh --drop-user

# Help
./db_manager.sh --help
```

## Usage Examples

### Initial project setup

1. **Create default configuration:**
```bash
# Edit db.defaults.conf for your project
nano db.defaults.conf
```

2. **Create database:**
```bash
./db_manager.sh --create-db
```

3. **Create user with access to the database:**
```bash
./db_manager.sh --create-user
```

or run in interactive mode and choose the respective options:
```bash
./db_manager.sh
```

4. **Save personal configuration** (will be offered during creation process)

**Note:** You can now create database and user separately, which provides more flexibility for complex setups.

### Backup

```bash
# Create backup
./db_manager.sh --backup
# Creates files: actual_db_YYMMDDHHNN.sql and current_db.sql
```

### Data restoration

```bash
# Restore from latest backup
./db_manager.sh --restore
# Uses current_db.sql by default
```

### Applying migrations

```bash
# Apply SQL file (with autocompletion)
./db_manager.sh --patch migrations/001_create_tables.sql

# Apply via pipe
cat migrateions/001_create_tables.sql | ./db_manager.sh --patch

# Or stdin
./db_manager.sh --patch < migrations/001_create_tables.sql
```

### Working with database

```bash
# Connect to DB in interactive mode
./db_manager.sh --connect
# Opens mysql client with automatic connection
```

## Security

### MySQL root password

**Option 1: Using saved password**
```bash
# In db.defaults.conf or db.conf
MYSQL_ROOT_PASSWORD="your_root_password"
```

**Option 2: Enter password at runtime (recommended)**
```bash
# Leave empty in configuration
MYSQL_ROOT_PASSWORD=""
```

### Delete operations

All delete operations require **double confirmation**:

1. **Confirm intention:** enter "yes"
2. **Confirm object:** enter exact DB/user name

**Example of DB deletion:**
```
WARNING! You are about to drop database:
  Database: myproject
  Host: localhost:3306

THIS ACTION IS IRREVERSIBLE! ALL DATA WILL BE LOST!

Type 'yes' to confirm deletion: yes
Repeat database name for final confirmation: myproject
```

## Configuration merge

The script uses a smart configuration merge system:

1. **Loads `db.defaults.conf`** (base values)
2. **Loads `db.conf`** (overwrites existing)
3. **For empty values in `db.conf`** - uses from `db.defaults.conf`
4. **For still empty values** - uses built-in constants

**Example:**
```bash
# db.defaults.conf
DBNAME="default_project"
DBUSER="default_user"
DBHOST="localhost"

# db.conf
DBNAME="my_project"  # overridden
DBUSER=""            # empty - will take from defaults
# DBHOST missing      # will take from defaults

# Result:
# DBNAME="my_project"
# DBUSER="default_user"
# DBHOST="localhost"
```

## File structure

After setup, directory structure:
```
db/
├── db_manager.sh          # Main script
├── db.defaults.conf       # Default configuration (in git)
├── db.conf               # Personal configuration (in .gitignore)
├── locales/              # Translation files
│   ├── ru.sh             # Russian localization
│   └── en.sh             # English localization
├── localdb/              # Backup directory
│   ├── actual_db_YYMMDDHHNN.sql
│   └── current_db.sql
└── README.md             # This documentation
```

## Requirements

- **MySQL/MariaDB** server
- **Bash** 4.0+
- **MySQL client** (mysql command)
- **Root access** to MySQL server

## Support

The script logs all operations with colored output:
- 🟢 **[INFO]** - successful operations
- 🟡 **[WARN]** - warnings
- 🔴 **[ERROR]** - errors
- 🔵 **[DB MANAGER]** - section headers

For debugging, a special mode is available:
```bash
./db_manager.sh --debug-config  # Shows final configuration
```
