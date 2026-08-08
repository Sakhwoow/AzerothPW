#!/bin/bash
set -e

# ─────────────────────────────────────────────
# AzerothPW — Perfect World 1.5.5 installer
# Ubuntu 22.04 x64, клиент el-156 Build 2567
# ─────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Параметры (можно переопределить env) ──
PW_DIR="${PW_DIR:-/opt/pw}"
PUBLIC_IP="${PUBLIC_IP:-}"
MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-pwuser}"
MYSQL_PASS="${MYSQL_PASS:-pwpassword}"
MYSQL_DB="${MYSQL_DB:-pw}"
PW_USER="${PW_USER:-pwserver}"

# ── Получить IP если не задан ──
if [ -z "$PUBLIC_IP" ]; then
    PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')
    info "Определён публичный IP: $PUBLIC_IP"
fi

info "=== AzerothPW Install ==="
info "Директория: $PW_DIR"
info "IP сервера: $PUBLIC_IP"
info "MySQL: $MYSQL_HOST:$MYSQL_PORT/$MYSQL_DB"

# ── 1. Зависимости ──
info "Устанавливаю зависимости..."
apt-get update -qq
apt-get install -y -qq \
    lib32gcc-s1 \
    libc6-i386 \
    lib32stdc++6 \
    libmysqlclient21 \
    openjdk-11-jre-headless \
    mysql-client \
    wget curl

# ── 2. Пользователь ──
if ! id "$PW_USER" &>/dev/null; then
    useradd -r -s /bin/false -d "$PW_DIR" "$PW_USER"
    info "Пользователь $PW_USER создан"
fi

# ── 3. Копирование файлов ──
info "Копирую файлы в $PW_DIR..."
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR"/{glinkd,gdeliveryd,gamed,gamedbd,authd,logservice,uniquenamed,gfactiond,gacd} "$PW_DIR/"

# ── 4. libtask.so для gamed ──
ln -sf "$PW_DIR/gamed/libtask.so.2" /usr/lib/i386-linux-gnu/libtask.so.2
ldconfig

# ── 5. MySQL база ──
info "Создаю базу данных..."
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u root -p <<SQL
CREATE DATABASE IF NOT EXISTS \`$MYSQL_DB\` CHARACTER SET utf8;
CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASS';
GRANT ALL ON \`$MYSQL_DB\`.* TO '$MYSQL_USER'@'%';
FLUSH PRIVILEGES;
SQL
mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$MYSQL_DB" < "$SCRIPT_DIR/sql/schema.sql"
info "База данных создана"

# ── 6. Конфиги (замена плейсхолдеров) ──
info "Генерирую конфиги..."
for tmpl in $(find "$PW_DIR" -name "*.tmpl"); do
    out="${tmpl%.tmpl}"
    sed \
        -e "s|{PUBLIC_IP}|$PUBLIC_IP|g" \
        -e "s|{MYSQL_HOST}|$MYSQL_HOST|g" \
        -e "s|{MYSQL_PORT}|$MYSQL_PORT|g" \
        -e "s|{MYSQL_USER}|$MYSQL_USER|g" \
        -e "s|{MYSQL_PASS}|$MYSQL_PASS|g" \
        -e "s|{MYSQL_DB}|$MYSQL_DB|g" \
        "$tmpl" > "$out"
done

# ── 7. Права ──
chmod +x "$PW_DIR"/glinkd/glinkd \
         "$PW_DIR"/gdeliveryd/gdeliveryd \
         "$PW_DIR"/gamed/gs \
         "$PW_DIR"/gamedbd/gamedbd \
         "$PW_DIR"/gamedbd/dbtool \
         "$PW_DIR"/authd/authd \
         "$PW_DIR"/logservice/logservice \
         "$PW_DIR"/uniquenamed/uniquenamed \
         "$PW_DIR"/gfactiond/gfactiond \
         "$PW_DIR"/gacd/gacd
chown -R "$PW_USER:$PW_USER" "$PW_DIR"

# ── 8. systemd ──
info "Устанавливаю systemd сервисы..."
cp "$SCRIPT_DIR"/systemd/*.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable pw-logservice pw-uniquenamed pw-gamedbd pw-authd \
                 pw-gfactiond pw-gacd pw-gdeliveryd pw-glinkd pw-gamed

# ── 9. Firewall ──
if command -v ufw &>/dev/null; then
    ufw allow 29000/tcp
    info "Порт 29000 открыт в ufw"
fi

info "=== Установка завершена ==="
info "Запуск: systemctl start pw-logservice pw-uniquenamed pw-gamedbd pw-authd pw-gfactiond pw-gacd pw-gdeliveryd pw-glinkd pw-gamed"
info "Статус: systemctl status pw-glinkd"
