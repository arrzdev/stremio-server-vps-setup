#!/bin/bash

###############################################################################
# Stremio Server Automated Setup Script
# This script automates the complete installation and configuration of:
# - Docker & Docker Compose
# - Stremio Server in Docker
# - Nginx reverse proxy
# - SSL certificate with Certbot
# - System optimizations
###############################################################################

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   log_error "This script must be run as root (use sudo)"
   exit 1
fi

# Banner
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║     Stremio Server Automated Setup Script            ║
║     Version 1.0                                       ║
╚═══════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Prompt for configuration
echo ""
log_info "Please provide the following information:"
echo ""

read -p "Enter your domain (e.g., stremio.example.com): " DOMAIN
read -p "Enter your email for SSL certificate: " EMAIL
read -p "Enter installation directory (default: /root/stremio-server): " INSTALL_DIR
INSTALL_DIR=${INSTALL_DIR:-/root/stremio-server}

# Confirm settings
echo ""
log_info "Configuration Summary:"
echo "  Domain: $DOMAIN"
echo "  Email: $EMAIL"
echo "  Installation Directory: $INSTALL_DIR"
echo ""
read -p "Continue with these settings? (y/n): " CONFIRM

if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    log_error "Setup cancelled by user"
    exit 1
fi

###############################################################################
# Step 1: System Update
###############################################################################
log_info "Step 1/9: Updating system packages..."
apt update && apt upgrade -y
apt install -y curl git ufw software-properties-common
log_success "System updated"

###############################################################################
# Step 2: Install Docker
###############################################################################
log_info "Step 2/9: Installing Docker..."

if command -v docker &> /dev/null; then
    log_warning "Docker is already installed, skipping..."
else
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl start docker
    systemctl enable docker
    log_success "Docker installed and enabled"
fi

###############################################################################
# Step 3: Install Docker Compose
###############################################################################
log_info "Step 3/9: Installing Docker Compose..."

if command -v docker-compose &> /dev/null; then
    log_warning "Docker Compose is already installed, skipping..."
else
    apt install -y docker-compose
    log_success "Docker Compose installed"
fi

###############################################################################
# Step 4: Create Stremio Server Setup
###############################################################################
log_info "Step 4/9: Setting up Stremio Server..."

mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3'

services:
  stremio:
    image: stremio/server:latest
    container_name: stremio-server
    restart: unless-stopped
    ports:
      - "127.0.0.1:11470:11470"
    environment:
      - NO_CORS=1
    volumes:
      - ./data:/root/.stremio-server
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
COMPOSE_EOF

log_success "Docker Compose configuration created"

###############################################################################
# Step 5: Start Stremio Server
###############################################################################
log_info "Step 5/9: Starting Stremio Server..."
docker-compose up -d

# Wait for container to be ready
sleep 5

if docker ps | grep -q stremio-server; then
    log_success "Stremio Server is running"
else
    log_error "Failed to start Stremio Server"
    exit 1
fi

###############################################################################
# Step 6: Install and Configure Nginx
###############################################################################
log_info "Step 6/9: Installing and configuring Nginx..."

if command -v nginx &> /dev/null; then
    log_warning "Nginx is already installed"
else
    apt install -y nginx
    systemctl start nginx
    systemctl enable nginx
    log_success "Nginx installed and enabled"
fi

# Create Nginx configuration
cat > "/etc/nginx/sites-available/$DOMAIN" << NGINX_EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;

    # Increase buffer sizes for streaming
    client_max_body_size 100M;
    client_body_buffer_size 128k;
    
    location / {
        proxy_pass http://127.0.0.1:11470;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Standard proxy headers
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Timeouts for streaming
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
        proxy_read_timeout 300s;
        send_timeout 300s;
        
        # Buffering optimization
        proxy_buffering off;
        proxy_request_buffering off;
        tcp_nodelay on;
    }
}
NGINX_EOF

# Enable site
ln -sf "/etc/nginx/sites-available/$DOMAIN" "/etc/nginx/sites-enabled/$DOMAIN"

# Remove default site if exists
rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
nginx -t
systemctl reload nginx

log_success "Nginx configured for $DOMAIN"

###############################################################################
# Step 7: Configure Firewall
###############################################################################
log_info "Step 7/9: Configuring firewall..."

# Check if UFW is active
if ufw status | grep -q "Status: active"; then
    log_warning "UFW is already active"
else
    ufw --force enable
fi

ufw allow OpenSSH
ufw allow 'Nginx Full'

log_success "Firewall configured"

###############################################################################
# Step 8: Install Certbot and Setup SSL
###############################################################################
log_info "Step 8/9: Installing Certbot and setting up SSL..."

# Check DNS resolution
log_info "Checking DNS resolution for $DOMAIN..."
if ! nslookup "$DOMAIN" > /dev/null 2>&1; then
    log_error "DNS resolution failed for $DOMAIN"
    log_error "Please ensure your domain is pointing to this server's IP before continuing"
    exit 1
fi

SERVER_IP=$(curl -s ifconfig.me)
DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)

log_info "Server IP: $SERVER_IP"
log_info "Domain IP: $DOMAIN_IP"

if [[ "$SERVER_IP" != "$DOMAIN_IP" ]]; then
    log_warning "Domain IP doesn't match server IP!"
    log_warning "SSL certificate may fail. Continue anyway? (y/n)"
    read -p "> " DNS_CONFIRM
    if [[ ! $DNS_CONFIRM =~ ^[Yy]$ ]]; then
        log_error "Setup cancelled. Please fix DNS and try again."
        exit 1
    fi
fi

# Install Certbot
if command -v certbot &> /dev/null; then
    log_warning "Certbot is already installed"
else
    apt install -y certbot python3-certbot-nginx
    log_success "Certbot installed"
fi

# Obtain SSL certificate
log_info "Obtaining SSL certificate..."
certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos --email "$EMAIL" --redirect

if [[ $? -eq 0 ]]; then
    log_success "SSL certificate obtained and configured"
else
    log_error "Failed to obtain SSL certificate"
    log_error "You can try running manually: sudo certbot --nginx -d $DOMAIN"
fi

# Test auto-renewal
certbot renew --dry-run

log_success "SSL auto-renewal configured"

###############################################################################
# Step 9: System Optimizations
###############################################################################
log_info "Step 9/9: Applying system optimizations..."

# Check if optimizations already exist
if grep -q "# Stremio Server Optimizations" /etc/sysctl.conf; then
    log_warning "System optimizations already applied, skipping..."
else
    cat >> /etc/sysctl.conf << 'SYSCTL_EOF'

# Stremio Server Optimizations
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_mtu_probing = 1
SYSCTL_EOF

    sysctl -p
    log_success "System optimizations applied"
fi

###############################################################################
# Final Steps and Information
###############################################################################
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           Setup Complete! 🎉                          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
log_success "Stremio Server is now running!"
echo ""
echo "📋 Setup Summary:"
echo "  ✓ Docker & Docker Compose installed"
echo "  ✓ Stremio Server running in Docker"
echo "  ✓ Nginx reverse proxy configured"
echo "  ✓ SSL certificate installed"
echo "  ✓ Firewall configured"
echo "  ✓ System optimized for streaming"
echo ""
echo "🌐 Your Stremio Server URL: https://$DOMAIN"
echo "📁 Installation Directory: $INSTALL_DIR"
echo ""
echo "📝 Useful Commands:"
echo "  • View logs: cd $INSTALL_DIR && docker-compose logs -f"
echo "  • Restart server: cd $INSTALL_DIR && docker-compose restart"
echo "  • Stop server: cd $INSTALL_DIR && docker-compose down"
echo "  • Start server: cd $INSTALL_DIR && docker-compose up -d"
echo "  • Update server: cd $INSTALL_DIR && docker-compose pull && docker-compose up -d"
echo ""
echo "🔐 SSL Certificate:"
echo "  • Certificates will auto-renew"
echo "  • Check status: sudo certbot certificates"
echo "  • Test renewal: sudo certbot renew --dry-run"
echo ""
echo "🔥 Firewall Status:"
ufw status numbered
echo ""
echo "✨ You can now configure your Stremio clients to use: https://$DOMAIN"
echo ""
