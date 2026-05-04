#!/bin/bash
# GitHub Actions Production Deployment - Quick Start

cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║   EMPLOYEE MANAGEMENT SYSTEM - GITHUB ACTIONS CI/CD SETUP                ║
║                                                                            ║
║   🚀 Production Deployment to AWS EC2 (Non-Docker)                       ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

📋 WHAT'S BEEN CREATED FOR YOU:
═══════════════════════════════════════════════════════════════════════════

✅ .github/workflows/production.yml
   ├─ Builds backend (Maven/Java)
   ├─ Builds frontend (Angular)
   ├─ Runs tests
   ├─ Deploys to AWS EC2 via SSH
   └─ Automatic health checks

✅ .github/workflows/ci.yml
   ├─ Runs on pull requests & develop branch
   ├─ Backend tests & build
   ├─ Frontend tests & build
   ├─ Code quality checks
   └─ Security scanning (Trivy, Dependency Check)

✅ EC2_DEPLOYMENT_GUIDE.md
   ├─ Complete EC2 setup instructions
   ├─ Nginx configuration
   ├─ Systemd service setup
   ├─ Database connection setup
   └─ Troubleshooting guide

✅ GITHUB_SECRETS_SETUP.md
   ├─ How to configure 8 GitHub Secrets
   ├─ Where to find AWS credentials
   ├─ EC2 SSH key setup
   └─ Database credentials format


⚡ QUICK START (4 STEPS):
═══════════════════════════════════════════════════════════════════════════

STEP 1: Configure GitHub Secrets
───────────────────────────────────
1. Go to GitHub repo → Settings → Secrets and variables → Actions
2. Add 8 secrets (see GITHUB_SECRETS_SETUP.md for details):
   • AWS_ACCESS_KEY_ID
   • AWS_SECRET_ACCESS_KEY
   • EC2_HOST
   • EC2_USER
   • EC2_PRIVATE_KEY
   • DB_URL
   • DB_USER
   • DB_PASSWORD

⏱️ Time: ~5 minutes


STEP 2: Setup AWS EC2 Instance
───────────────────────────────
1. Launch Ubuntu 22.04 LTS on AWS EC2 (t3.medium or larger)
2. Update security group to allow:
   • Port 22 (SSH) - your IP only
   • Port 80 (HTTP) - all
   • Port 443 (HTTPS) - all
   • Port 8080 (Backend) - internal only
3. SSH into instance and run setup script:
   • See EC2_DEPLOYMENT_GUIDE.md → Step 2.3

⏱️ Time: ~10 minutes


STEP 3: Setup RDS MySQL Database
──────────────────────────────────
1. Create RDS MySQL instance on AWS (8.0)
2. Enable public accessibility (or use VPC endpoint)
3. Create database: 'employeedb'
4. Note down endpoint, user, and password
5. Update GitHub Secrets with DB credentials

⏱️ Time: ~5 minutes


STEP 4: Deploy
───────────────
1. Commit and push to 'main' branch:
   $ git add .github/workflows/ *.md
   $ git commit -m "Add GitHub Actions CI/CD workflow"
   $ git push origin main

2. Monitor deployment:
   • GitHub → Actions tab
   • Watch workflow execution
   • Check logs for any errors

3. Access your app:
   • Frontend: http://YOUR_EC2_IP
   • Backend API: http://YOUR_EC2_IP:8080/api/v1/employees
   • Health: http://YOUR_EC2_IP:8080/actuator/health

⏱️ Time: ~2 minutes


🔄 WORKFLOW EXPLAINED:
═══════════════════════════════════════════════════════════════════════════

When you push to 'main':
┌─────────────────────────┐
│   Push to main branch   │
└────────┬────────────────┘
         │
    ┌────▼────────────────┐
    │  GitHub Actions     │
    │  (production.yml)   │
    └────┬────────────────┘
         │
    ┌────▼─────────────────┬─────────────────┐
    │  Build Backend      │  Build Frontend │
    │  (Maven + Tests)    │  (Angular Build)│
    └────┬─────────────────┴────┬────────────┘
         │                      │
    ┌────▼──────────────────────▼──────┐
    │  Deploy to EC2 via SSH           │
    │  1. Upload JAR file              │
    │  2. Upload frontend dist files   │
    │  3. Start backend service        │
    │  4. Reload Nginx                 │
    │  5. Health checks                │
    └────┬──────────────────────────────┘
         │
    ┌────▼──────────────────────────────┐
    │  ✅ Application Live              │
    │  Frontend: Served by Nginx        │
    │  Backend: Running as service      │
    │  Database: RDS MySQL              │
    └───────────────────────────────────┘


📚 DETAILED DOCUMENTATION:
═════════════════════════════════════════════════════════════════════════════

File                              Purpose
────────────────────────────────  ───────────────────────────────────────────
.github/workflows/production.yml   Main deployment workflow (AWS EC2)
.github/workflows/ci.yml           Testing workflow (PR & develop branch)
EC2_DEPLOYMENT_GUIDE.md            Complete step-by-step EC2 setup
GITHUB_SECRETS_SETUP.md            How to configure all 8 secrets
.env.example                       Environment variables template
.gitignore                         Prevents secrets from being committed
docker-compose.yml                 For local Docker development (reference)


✨ WHAT HAPPENS AUTOMATICALLY:
═════════════════════════════════════════════════════════════════════════════

✓ On every push to main:
  • GitHub Actions builds backend & frontend
  • Runs all tests
  • If tests pass, deploys to EC2
  • Nginx serves frontend on port 80
  • Backend service runs on port 8080
  • MySQL RDS handles persistence
  • Health checks verify everything is running

✓ Pull requests to main:
  • CI tests run (but no deployment)
  • Code quality checks
  • Security scanning (Trivy)
  • Must pass before merging

✓ Manual actions:
  • Push to develop: runs tests only
  • GitHub Actions tab: See all runs
  • View logs for each step
  • Manual rollback available (via workflow_dispatch)


🔒 SECURITY FEATURES:
═════════════════════════════════════════════════════════════════════════════

✓ Secrets securely managed by GitHub
✓ SSH key-based EC2 access (no passwords)
✓ RDS runs in private VPC (optional)
✓ Health checks verify service health
✓ Automated rollback on failure
✓ Encrypted in-transit communication
✓ Nginx security headers configured


📊 MONITORING & LOGS:
═════════════════════════════════════════════════════════════════════════════

View GitHub Actions Logs:
$ gh run list --repo your-username/repo-name

View EC2 Logs:
$ ssh ubuntu@your-ec2-ip
$ sudo journalctl -u employee-backend -f    # Backend logs
$ sudo tail -f /var/log/nginx/access.log    # Nginx logs

Test Backend Health:
$ curl http://your-ec2-ip:8080/actuator/health

Test API:
$ curl http://your-ec2-ip/api/v1/employees


🆘 TROUBLESHOOTING:
═════════════════════════════════════════════════════════════════════════════

Issue: "Permission denied (publickey)"
Solution: Check EC2_PRIVATE_KEY in secrets - must be full PEM content

Issue: "Cannot connect to RDS"
Solution: Check DB_URL format and RDS security group rules

Issue: "Backend not starting"
Solution: Check EC2 logs (see Monitoring section above)

Issue: "Frontend not loading"
Solution: Check Nginx config and /home/ubuntu/employee-app/frontend ownership

See EC2_DEPLOYMENT_GUIDE.md for more troubleshooting


🚀 NEXT STEPS:
═════════════════════════════════════════════════════════════════════════════

1. ✏️  Update GITHUB_SECRETS_SETUP.md with your AWS info
2. 🔐 Add all 8 secrets to GitHub repository
3. 🖥️  Setup EC2 instance and run dependency installation
4. 📦 Setup RDS MySQL database  
5. 🔄 Push to main branch and watch GitHub Actions
6. 🌍 Access your live application!


📞 SUPPORT:
═════════════════════════════════════════════════════════════════════════════

For issues, check:
1. GitHub Actions workflow logs
2. EC2 system logs (via SSH)
3. Nginx error logs
4. Backend application logs
5. RDS connectivity

All detailed in EC2_DEPLOYMENT_GUIDE.md


═══════════════════════════════════════════════════════════════════════════

Happy deploying! 🎉

Your application is now ready for production deployment with:
✅ Automated CI/CD pipeline
✅ Multi-step testing
✅ Secure secrets management
✅ AWS EC2 deployment
✅ RDS MySQL database
✅ Nginx reverse proxy
✅ Health monitoring
✅ Automated rollbacks

═══════════════════════════════════════════════════════════════════════════

EOF
