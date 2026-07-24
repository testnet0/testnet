#!/bin/bash

# 设置证书目录
CERT_DIR="$(dirname "$0")/certs"
mkdir -p "$CERT_DIR"

# 生成自签名证书
echo "Generating self-signed certificate in $CERT_DIR..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "$CERT_DIR/server.key" \
  -out "$CERT_DIR/server.crt" \
  -subj "/C=CN/ST=Beijing/L=Beijing/O=TestNet/OU=Dev/CN=localhost"

echo "Certificate generation complete:"
ls -l "$CERT_DIR"
