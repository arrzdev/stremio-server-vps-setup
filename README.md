# Stremio Server Automated Setup

This repository contains an automated installation script for setting up a complete Stremio Server on a VPS with Docker, Nginx reverse proxy, and SSL certificate.

## 🚀 Quick Start

### Prerequisites

- A fresh Ubuntu/Debian VPS (20.04, 22.04, or 24.04)
- Root access to the server
- A domain name with DNS A record pointing to your VPS IP
- SSH access to your server

### One-Line Installation

```bash
wget https://raw.githubusercontent.com/yourusername/stremio-server-setup/main/stremio-setup.sh && sudo bash stremio-setup.sh
```

Or download and run manually:

```bash
# Download the script
wget https://raw.githubusercontent.com/yourusername/stremio-server-setup/main/stremio-setup.sh

# Make it executable
chmod +x stremio-setup.sh

# Run the script
sudo ./stremio-setup.sh
```

### Manual Setup

1. **Copy the script to your server:**
   ```bash
   scp stremio-setup.sh root@your-server-ip:/root/
   ```

2. **SSH into your server:**
   ```bash
   ssh root@your-server-ip
   ```

3. **Make the script executable:**
   ```bash
   chmod +x stremio-setup.sh
   ```

4. **Run the script:**
   ```bash
   ./stremio-setup.sh
   ```

5. **Follow the prompts:**
   - Enter your domain (e.g., `stremio.example.com`)
   - Enter your email for SSL certificate
   - Choose installation directory (or press Enter for default)
   - Confirm settings

## 📋 What the Script Does

The script automatically performs the following steps:

1. ✅ Updates system packages
2. ✅ Installs Docker and Docker Compose
3. ✅ Creates and starts Stremio Server container
4. ✅ Installs and configures Nginx as reverse proxy
5. ✅ Configures UFW firewall
6. ✅ Installs Certbot and obtains SSL certificate
7. ✅ Applies system optimizations for streaming
8. ✅ Sets up auto-start on boot
9. ✅ Configures automatic SSL renewal

## 🔧 Post-Installation

After successful installation, your Stremio Server will be accessible at:

```
https://your-domain.com
```

### Useful Commands

**View Logs:**
```bash
cd /root/stremio-server
docker-compose logs -f
```

**Restart Server:**
```bash
cd /root/stremio-server
docker-compose restart
```

**Stop Server:**
```bash
cd /root/stremio-server
docker-compose down
```

**Start Server:**
```bash
cd /root/stremio-server
docker-compose up -d
```

**Update Server:**
```bash
cd /root/stremio-server
docker-compose pull
docker-compose up -d
```

**Check SSL Certificate:**
```bash
sudo certbot certificates
```

**Test SSL Renewal:**
```bash
sudo certbot renew --dry-run
```

**Check Firewall Status:**
```bash
sudo ufw status
```

**Check Nginx Status:**
```bash
sudo systemctl status nginx
```

**View Nginx Logs:**
```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

## 🔍 Troubleshooting

### DNS Issues

If SSL certificate fails, ensure your domain's DNS is properly configured:

```bash
# Check DNS resolution
nslookup your-domain.com

# Check your server's IP
curl ifconfig.me
```

The domain should resolve to your server's IP address. DNS changes can take up to 48 hours to propagate.

### Port Already in Use

If port 80 or 443 is already in use:

```bash
# Check what's using the ports
sudo lsof -i :80
sudo lsof -i :443

# Stop conflicting services if needed
sudo systemctl stop apache2  # if Apache is running
```

### Container Won't Start

Check Docker logs:

```bash
cd /root/stremio-server
docker-compose logs
```

### Nginx Configuration Issues

Test Nginx configuration:

```bash
sudo nginx -t
```

If there are errors, check the configuration file:

```bash
sudo nano /etc/nginx/sites-available/your-domain.com
```

### SSL Certificate Issues

If Certbot fails:

1. Ensure ports 80 and 443 are open
2. Verify DNS is pointing to your server
3. Try manual certificate issuance:

```bash
sudo certbot --nginx -d your-domain.com
```

## 🛡️ Security Considerations

The script automatically:
- Configures UFW firewall
- Enables HTTPS with strong SSL settings
- Binds Stremio to localhost (only accessible via Nginx)
- Adds security headers to Nginx

Additional security recommendations:
- Use SSH keys instead of passwords
- Change the default SSH port
- Set up fail2ban for brute force protection
- Regularly update your system

## 📊 System Requirements

**Minimum:**
- 1 CPU core
- 1 GB RAM
- 10 GB storage
- Ubuntu 20.04+ or Debian 10+

**Recommended:**
- 2 CPU cores
- 2 GB RAM
- 20 GB storage
- Ubuntu 22.04 or Debian 11

## 🔄 Updating Stremio Server

To update to the latest version:

```bash
cd /root/stremio-server
docker-compose pull
docker-compose up -d
```

The script sets up Docker with auto-restart, so the server will automatically start on system reboot.

## 🗑️ Uninstallation

To completely remove Stremio Server:

```bash
# Stop and remove containers
cd /root/stremio-server
docker-compose down -v

# Remove installation directory
rm -rf /root/stremio-server

# Remove Nginx configuration
sudo rm /etc/nginx/sites-available/your-domain.com
sudo rm /etc/nginx/sites-enabled/your-domain.com
sudo systemctl reload nginx

# Remove SSL certificate (optional)
sudo certbot delete --cert-name your-domain.com
```

## 📝 Configuration Files

**Docker Compose:** `/root/stremio-server/docker-compose.yml`
**Nginx Config:** `/etc/nginx/sites-available/your-domain.com`
**SSL Certificates:** `/etc/letsencrypt/live/your-domain.com/`
**Stremio Data:** `/root/stremio-server/data/`

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

MIT License - Feel free to use and modify as needed.

## ⚠️ Disclaimer

This script is provided as-is. Always review scripts before running them with root privileges. Use at your own risk.

## 💬 Support

For issues related to:
- **This script:** Open an issue on GitHub
- **Stremio Server:** Visit [Stremio's official support](https://www.stremio.com/)
- **VPS setup:** Consult your VPS provider's documentation

## 🎯 Features

- ✅ Fully automated installation
- ✅ One-command setup
- ✅ SSL/HTTPS enabled by default
- ✅ Auto-renewal of certificates
- ✅ Optimized for streaming performance
- ✅ Auto-start on system boot
- ✅ Firewall configured
- ✅ Production-ready configuration
- ✅ Easy management commands
- ✅ Comprehensive error handling

## 📈 Performance Tuning

The script automatically applies kernel optimizations for streaming. For additional tuning:

**Increase Cache Size:**
Edit the docker-compose.yml and add:
```yaml
environment:
  - CACHE_SIZE=4096  # Default is 2048 MB
```

**Adjust Transcoding:**
The server will use software transcoding by default (hardware acceleration requires specific hardware).

## 🌐 Using Your Stremio Server

Once installed, configure your Stremio clients:

1. Open Stremio app on your device
2. Go to Settings
3. Set Streaming Server to: `https://your-domain.com`
4. Enjoy streaming!

---

Made with ❤️ for the Stremio community
