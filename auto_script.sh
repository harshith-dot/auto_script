#!/bin/bash

echo "🚀 Auto SSH Setup Starting..."

# ================= CONFIG =================
DB_HOST="srv761.hstgr.io"
DB_USER="u731327990_servers"
DB_NAME="u731327990_servers"

NGROK_TOKEN="PASTE_LATER_OR_HERE"

# ================= ASK PASSWORD =================
read -s -p "Enter DB Password: " DB_PASS
echo ""

read -p "Enter Server IP: " SERVER_IP
read -p "Enter SSH User (default msfadmin): " SSH_USER
SSH_USER=${SSH_USER:-msfadmin}

# ================= CREATE USER =================
NEW_USER="user$(date +%s)"
NEW_PASS=$(openssl rand -base64 6)

echo "🔐 Creating SSH user..."

ssh $SSH_USER@$SERVER_IP << EOF
sudo useradd -m $NEW_USER
echo "$NEW_USER:$NEW_PASS" | sudo chpasswd
EOF

echo "✅ SSH User Created"
echo "Username: $NEW_USER"
echo "Password: $NEW_PASS"

# ================= INSTALL NGROK =================
echo "🌐 Installing ngrok..."

wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
tar -xzf ngrok-v3-stable-linux-amd64.tgz

# ================= AUTH =================
./ngrok config add-authtoken "$NGROK_TOKEN"

# ================= START NGROK =================
echo "🚀 Starting ngrok..."

./ngrok tcp 22 > ngrok.log &

sleep 6

# ================= GET URL =================
NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o 'tcp://[^"]*')

HOST=$(echo $NGROK_URL | cut -d':' -f2 | sed 's|//||')
PORT=$(echo $NGROK_URL | cut -d':' -f3)

echo "🌍 Public Host: $HOST"
echo "🌍 Port: $PORT"

# ================= INSERT INTO DB =================
echo "📡 Inserting into database..."

mysql -h $DB_HOST -u $DB_USER -p"$DB_PASS" $DB_NAME << EOF
INSERT INTO servers (name, host, port, username)
VALUES ('AutoServer', '$HOST', $PORT, '$NEW_USER');
EOF

echo "✅ Server added to DB!"

# ================= CLEANUP =================
rm -f ngrok ngrok.log ngrok-v3-stable-linux-amd64.tgz

echo "🎉 DONE!"
