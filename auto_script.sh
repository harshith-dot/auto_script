#!/bin/bash

echo "Auto SSH Setup Starting..."

# ================= CONFIG =================
DB_HOST="srv761.hstgr.io"
DB_USER="u731327990_servers"
DB_NAME="u731327990_servers"
NGROK_TOKEN="1dS4LyB2Xeay22UVx5imwjNhmMA_SdtqMhafUy2DPfgQGtHQ"

# ================= ASK PASSWORD =================
read -s -p "Enter DB Password: " DB_PASS
echo ""

read -p "Enter Server IP: " SERVER_IP
read -p "Enter SSH User (default msfadmin): " SSH_USER
SSH_USER=${SSH_USER:-msfadmin}

# ================= CHECK TOOLS =================
for cmd in ssh wget tar curl mysql openssl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "Missing required command: $cmd"
        exit 1
    fi
done

# ================= CREATE USER =================
NEW_USER="user$(date +%s)"
NEW_PASS=$(openssl rand -base64 6)

echo "Creating SSH user on remote server..."

ssh "$SSH_USER@$SERVER_IP" <<EOF
sudo useradd -m "$NEW_USER"
echo "$NEW_USER:$NEW_PASS" | sudo chpasswd
EOF

if [ $? -ne 0 ]; then
    echo "SSH user creation failed"
    exit 1
fi

echo "SSH User Created"
echo "Username: $NEW_USER"
echo "Password: $NEW_PASS"

# ================= INSTALL NGROK =================
echo "Installing ngrok..."

wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz -O ngrok.tgz
tar -xzf ngrok.tgz

if [ ! -f ./ngrok ]; then
    echo "ngrok download/extract failed"
    exit 1
fi

# ================= AUTH =================
./ngrok config add-authtoken "$NGROK_TOKEN"

# ================= START NGROK =================
echo "Starting ngrok..."
./ngrok tcp 22 > ngrok.log 2>&1 &

sleep 6

# ================= GET URL =================
NGROK_URL=$(curl -s http://127.0.0.1:4040/api/tunnels | grep -o 'tcp://[^"]*' | head -n 1)

if [ -z "$NGROK_URL" ]; then
    echo "Could not fetch ngrok URL"
    cat ngrok.log
    exit 1
fi

HOST=$(echo "$NGROK_URL" | cut -d: -f2 | sed 's#//# #g' | tr -d ' ')
PORT=$(echo "$NGROK_URL" | cut -d: -f3)

echo "Public Host: $HOST"
echo "Public Port: $PORT"

# ================= INSERT INTO DB =================
echo "Inserting into database..."

mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" <<EOF
INSERT INTO servers (name, host, port, username)
VALUES ('AutoServer', '$HOST', $PORT, '$NEW_USER');
EOF

if [ $? -ne 0 ]; then
    echo "Database insert failed"
    exit 1
fi

echo "Server added to DB"

# ================= CLEANUP =================
rm -f ngrok ngrok.log ngrok.tgz

echo "DONE!"
