# GitHub Secrets Configuration Guide

This guide explains how to configure all necessary secrets for the GitHub Actions production deployment workflow.

---

## Prerequisites

Before adding secrets, you need:

1. **AWS Account** with:
   - EC2 instance running (Ubuntu 22.04 LTS)
   - RDS MySQL database instance
   - IAM user with EC2 and RDS permissions

2. **SSH Key Pair** for EC2 access

3. **Database Credentials** for RDS MySQL

---

## Adding Secrets to GitHub

### Step 1: Navigate to Repository Settings

1. Go to your GitHub repository
2. Click **Settings** (top right)
3. In left sidebar, click **Secrets and variables** → **Actions**

### Step 2: Add Each Secret

Click **"New repository secret"** for each entry below:

---

## Required Secrets

### 1. AWS Credentials (for EC2 & RDS Access)

#### `AWS_ACCESS_KEY_ID`
- **Description**: AWS IAM user access key
- **Where to get it**:
  1. Go to AWS Console → IAM → Users
  2. Select your user → Security credentials tab
  3. Under "Access keys", click "Create access key"
  4. Copy the "Access key ID"
- **Example**: `AKIAIOSFODNN7EXAMPLE`

#### `AWS_SECRET_ACCESS_KEY`
- **Description**: AWS IAM user secret access key
- **Where to get it**:
  1. Same location as above
  2. Copy the "Secret access key" (only visible at creation time!)
  3. Store securely
- **Example**: `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY`

---

### 2. EC2 Connection Details

#### `EC2_HOST`
- **Description**: Public IP address or hostname of your EC2 instance
- **Where to get it**:
  1. AWS Console → EC2 → Instances
  2. Select your instance
  3. Copy "Public IPv4 address" or "Public IPv4 DNS name"
- **Example**: `54.123.45.67` or `ec2-54-123-45-67.compute-1.amazonaws.com`

#### `EC2_USER`
- **Description**: SSH username for EC2 instance
- **Default values**:
  - Ubuntu AMI: `ubuntu`
  - Amazon Linux: `ec2-user`
  - CentOS: `centos`
- **Example**: `ubuntu`

#### `EC2_PRIVATE_KEY`
- **Description**: Private SSH key for EC2 access (PEM format)
- **⚠️ IMPORTANT**: This is sensitive! Handle carefully.
- **How to get & format**:
  1. Your EC2 key pair file (ends with `.pem`)
  2. Open in text editor (e.g., `cat my-key.pem` in terminal)
  3. Copy **entire content** including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`
  4. Paste into GitHub secret (keep newlines intact)
- **Example**:
  ```
  -----BEGIN RSA PRIVATE KEY-----
  MIIEpAIBAAKCAQEA2Z3qX2BTLS39R3wvUL3...
  [many lines of key data]
  -----END RSA PRIVATE KEY-----
  ```

---

### 3. Database Configuration

#### `DB_URL`
- **Description**: JDBC connection string for RDS MySQL
- **Format**: `jdbc:mysql://[host]:[port]/[database]`
- **Where to get it**:
  1. AWS Console → RDS → Databases
  2. Select your MySQL instance
  3. Copy "Endpoint" (looks like `mydb.123abc456.us-east-1.rds.amazonaws.com`)
- **Example**: `jdbc:mysql://mydb.c9akciq32.us-east-1.rds.amazonaws.com:3306/employeedb`

#### `DB_USER`
- **Description**: RDS MySQL admin username
- **Default**: `admin` (unless you created different user)
- **Where to get it**:
  1. RDS database settings (you set this at creation)
  2. Usually documented in your setup notes
- **Example**: `admin`

#### `DB_PASSWORD`
- **Description**: RDS MySQL admin password
- **⚠️ IMPORTANT**: This is sensitive! Use strong password.
- **Best practices**:
  - Use auto-generated password from RDS
  - At least 12 characters, mixed case, numbers, symbols
  - Store in password manager
- **Example**: `MyP@ssw0rd!Secure123`

---

## Complete Checklist

Use this checklist to ensure all secrets are added:

```
AWS Credentials:
  ☐ AWS_ACCESS_KEY_ID
  ☐ AWS_SECRET_ACCESS_KEY

EC2 Connection:
  ☐ EC2_HOST
  ☐ EC2_USER
  ☐ EC2_PRIVATE_KEY

Database:
  ☐ DB_URL
  ☐ DB_USER
  ☐ DB_PASSWORD
```

---

## Verifying Secrets

After adding all secrets:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. You should see all 8 secrets listed
3. They will show as "●●●●●●●●" (masked for security)

---

## Testing Secrets

To test your configuration before deployment:

```bash
# Test SSH connection to EC2
ssh -i your-key.pem ec2-user@your-ec2-ip

# Test database connection
mysql -h your-rds-endpoint -u admin -p'your-password' -e "SHOW DATABASES;"
```

---

## Troubleshooting

### "Permission denied (publickey)" error
- Check `EC2_PRIVATE_KEY` format - ensure full PEM content
- Check `EC2_USER` matches your AMI type
- Ensure newlines are preserved in secret

### "Unknown database host" error
- Check `DB_URL` format - should include full RDS endpoint
- Ensure RDS security group allows inbound on port 3306 from EC2

### "Access denied for user" error  
- Check `DB_USER` and `DB_PASSWORD` are correct
- Verify user permissions in RDS

### Secrets still not working?
1. Check workflow logs: GitHub → Actions → workflow run
2. Verify all 8 secrets are present in Settings
3. Try re-entering secrets (copy-paste may miss characters)

---

## Security Best Practices

1. **Never commit secrets to Git**
   - `.env` files are in `.gitignore`
   - Only use GitHub Secrets

2. **Rotate credentials regularly**
   - AWS keys: every 90 days
   - Database password: every 6 months
   - SSH key: as needed

3. **Limit secret access**
   - Use IAM policies with minimal permissions
   - Restrict EC2 security groups by source IP
   - Use VPC endpoint for RDS if possible

4. **Audit secret usage**
   - GitHub logs secret access in Actions
   - AWS CloudTrail logs API calls
   - Review regularly for suspicious activity

---

## Reference

For more information:
- [GitHub Secrets Docs](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [RDS Security Groups](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Overview.DBSecurityGroup.html)
