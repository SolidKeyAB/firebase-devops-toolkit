#!/bin/bash

# Create self-signed certificate for local HTTPS proxy

CERT_DIR="${CERT_DIR:-$(pwd)/.certs}"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "🔐 Creating self-signed certificate for local HTTPS..."

# Get local IP if not provided
if [ -z "$LOCAL_NETWORK_IP" ]; then
    if command -v ip &> /dev/null; then
        LOCAL_NETWORK_IP=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' 2>/dev/null)
    elif command -v ipconfig &> /dev/null; then
        LOCAL_NETWORK_IP=$(ipconfig getifaddr en0 2>/dev/null)
    fi
fi
LOCAL_NETWORK_IP="${LOCAL_NETWORK_IP:-127.0.0.1}"

echo "📡 Using local IP: $LOCAL_NETWORK_IP"

# Create certificate configuration
cat > cert.conf << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = Development
L = Local
O = ${COMPANY_NAME:-"Firebase Emulator Proxy"}
CN = $LOCAL_NETWORK_IP

[v3_req]
basicConstraints = CA:FALSE
keyUsage = keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
IP.1 = $LOCAL_NETWORK_IP
IP.2 = 127.0.0.1
DNS.1 = localhost
EOF

# Generate private key and certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout key.pem \
    -out cert.pem \
    -config cert.conf

echo "✅ Certificate created successfully!"
echo "📄 Certificate: $CERT_DIR/cert.pem"
echo "🔑 Private key: $CERT_DIR/key.pem"