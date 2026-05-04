# EC2 Production Deployment Setup Guide

## Prerequisites

1. **AWS EC2 Instance** (Ubuntu 22.04 LTS recommended)
2. **RDS MySQL Database** configured and accessible
3. **Nginx** installed on EC2
4. **Java 21** installed on EC2
5. **SSH key pair** for EC2 access
---------------------------------

## Step 1: Configure GitHub Secrets

Add these secrets to your GitHub repository:

### AWS Credentials (for GitHub Actions)
- `AWS_ACCESS_KEY_ID` - IAM user access key
- `AWS_SECRET_ACCESS_KEY` - IAM user secret key

### EC2 Connection Credentials
- `EC2_HOST` - Your EC2 instance public IP/DNS (e.g., `54.123.45.67`)
- `EC2_USER` - SSH user (default: `ubuntu` for Ubuntu AMI)
- `EC2_PRIVATE_KEY` - EC2 instance private key (PEM format, paste full content)

### Database Configuration
- `DB_URL` - MySQL RDS connection string (e.g., `jdbc:mysql://mydb.rds.amazonaws.com:3306/employeedb`)
- `DB_USER` - RDS MySQL username (default: `admin`)
- `DB_PASSWORD` - RDS MySQL password

**How to add secrets:**
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Click "New repository secret"
3. Add each secret with the values above

---

## Step 2: EC2 Instance Setup

### 2.1 Launch EC2 Instance
```bash
# Launch Ubuntu 22.04 LTS t3.medium or larger
# Security group: Allow ports 22 (SSH), 80 (HTTP), 443 (HTTPS), 8080 (Backend)
```

### 2.2 Connect to EC2
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 2.3 Install Dependencies
```bash
#!/bin/bash

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Install Java 21
sudo apt-get install -y openjdk-21-jre-headless

# Install Nginx
sudo apt-get install -y nginx

# Install MySQL client (for connection testing)
sudo apt-get install -y mysql-client

# Install curl for health checks
sudo apt-get install -y curl

# Create app user
sudo useradd -m -s /bin/bash appuser
```

### 2.4 Create Application Directory
```bash
sudo mkdir -p /home/ubuntu/employee-app/backend
sudo mkdir -p /home/ubuntu/employee-app/frontend
sudo chown -R ubuntu:ubuntu /home/ubuntu/employee-app
```

---

## Step 3: Configure Systemd Service for Backend

Create `/etc/systemd/system/employee-backend.service`:

```ini
[Unit]
Description=Employee Management System Backend
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/employee-app/backend

Environment="JAVA_OPTS=-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+ExitOnOutOfMemoryError -XX:+UseG1GC"
Environment="SPRING_PROFILES_ACTIVE=prod"

ExecStart=/usr/bin/java $JAVA_OPTS -jar emp_backend-0.0.1-SNAPSHOT.jar

Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable employee-backend
```

---

## Step 4: Configure Nginx for Frontend

Create or update `/etc/nginx/sites-available/employee-app`:

```nginx
upstream backend_server {
    server localhost:8080;
    keepalive 32;
}

server {
    listen 80 default_server;
    server_name _;
    client_max_body_size 10M;

    root /home/ubuntu/employee-app/frontend;
    index index.html;

    # Security Headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    # API Proxy
    location /api/v1/ {
        proxy_pass http://backend_server/api/v1/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Static files
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # SPA fallback
    location / {
        try_files $uri $uri/ /index.html;
        expires -1;
    }
}
```

Enable the site:
```bash
sudo ln -sf /etc/nginx/sites-available/employee-app /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

---

## Step 5: Test the Deployment Manually

```bash
# Test database connection
mysql -h your-rds-endpoint -u admin -p -e "SHOW DATABASES;"

# Generate SSH key for GitHub Actions (if not already done)
ssh-keygen -t ed25519 -f github-deploy-key

# Add public key to EC2
cat github-deploy-key.pub >> ~/.ssh/authorized_keys

# Copy private key to GitHub Secrets (EC2_PRIVATE_KEY)
cat github-deploy-key
```

---

## Step 6: Deploy via GitHub Actions

1. Commit and push to `main` branch:
```bash
git add .github/workflows/production.yml
git commit -m "Add production deployment workflow"
git push origin main
```

2. Monitor deployment:
   - Go to GitHub repo → Actions
   - Watch the workflow execution

3. Access your application:
   - Frontend: `http://your-ec2-ip`
   - Backend: `http://your-ec2-ip:8080/api/v1/employees`
   - Health check: `http://your-ec2-ip:8080/actuator/health`

---

## Monitoring & Troubleshooting

### Check service status
```bash
sudo systemctl status employee-backend
sudo systemctl status nginx
```

### View logs
```bash
# Backend logs
sudo journalctl -u employee-backend -f

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Test endpoints
```bash
# Backend health
curl http://localhost:8080/actuator/health

# API endpoint
curl http://localhost:8080/api/v1/employees

# Frontend
curl http://localhost/
```

### Restart services
```bash
sudo systemctl restart employee-backend
sudo systemctl restart nginx
```

---

## Security Best Practices

1. **Update EC2 Security Group:**
   - Restrict SSH (port 22) to your IP only
   - Allow ports 80 & 443 globally (HTTP/HTTPS)
   - Allow port 8080 for internal health checks

2. **Enable HTTPS (SSL):**
   ```bash
   sudo apt-get install certbot python3-certbot-nginx
   sudo certbot --nginx -d yourdomain.com
   ```

3. **Backup RDS Database:**
   - Enable automated backups in AWS RDS
   - Set retention to at least 7 days

4. **Rotate Secrets:**
   - Regularly rotate DB passwords and AWS keys
   - Update GitHub Secrets quarterly

5. **Monitor Logs:**
   - Set up CloudWatch logs
   - Configure alarms for errors

---

## Rollback Procedure

If deployment fails:
```bash
# GitHub Actions can manually trigger rollback
# Or manually on EC2:

sudo systemctl restart employee-backend
# Previous JAR is preserved if you keep backups
```

---

## Useful Commands

```bash
# Check GitHub Actions status
gh run list --repo your-username/employee-management-system

# View workflow run details
gh run view RUN_ID --repo your-username/employee-management-system

# Manual deployment trigger via CLI
gh workflow run production.yml --ref main
```

---

For more help, check GitHub Actions logs or EC2 system logs!
