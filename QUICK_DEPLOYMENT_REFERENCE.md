# Quick Deployment Reference Card

## System Information

**API Endpoint:** https://api.blacksteep.com  
**Frontend:** https://d2b386ss3jk33z.cloudfront.net  
**Region:** us-east-1  
**Environment:** Production

## Pre-Flight Checklist

```bash
# 1. Check prerequisites
aws --version
terraform --version
docker --version
node --version
agentcore --version

# 2. Set environment
export AWS_REGION=us-east-1
export ENVIRONMENT=production
export ALERT_EMAIL=adelanaj@amazon.co.uk

# 3. Verify credentials
aws sts get-caller-identity
```

## Quick Deploy (Automated)

```bash
cd backend
./scripts/deploy_production.sh
```

## Manual Deploy Steps

### 1. Infrastructure (15-20 min)

```bash
cd infrastructure/terraform/environments/prod
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### 2. Database (1-2 min)

```bash
cd backend
export DATABASE_URL="postgresql://user:pass@<RDS_ENDPOINT>/db"
alembic upgrade head
```

### 3. Backend (5-10 min)

```bash
cd backend
docker build -t cms-backend:latest .
docker tag cms-backend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/cms-backend:latest
aws ecr get-login-password | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/cms-backend:latest
aws ecs update-service --cluster cms-cluster --service cms-service --force-new-deployment
```

### 4. Frontend (5-10 min)

**Important**: Next.js static export creates files in `out/` directory

```bash
cd frontend
npm ci && npm run build
aws s3 sync out/ s3://content-marketing-swarm-dev-frontend/ --delete --exclude "*.txt"
aws cloudfront create-invalidation --distribution-id EOKK53AQTTMGG --paths "/*"

# Or use the deployment script
./deploy-frontend.sh
```

### 5. Agents (5-10 min)

```bash
cd backend
./scripts/package_agents.sh
./scripts/deploy_to_agentcore.sh
./scripts/verify_deployment.sh
```

### 6. Monitoring (2-3 min)

```bash
cd backend
./scripts/setup_monitoring.sh
```

## Quick Tests

### Smoke Tests

```bash
# Health check
curl http://${ALB_DNS}/health

# API check
curl http://${ALB_DNS}/api/health

# Content generation
curl -X POST http://${ALB_DNS}/api/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Test","user_id":"test","platforms":["linkedin"]}'
```

### E2E Tests

```bash
cd backend
export STAGING_API_URL="http://${ALB_DNS}"
pytest tests/test_e2e_staging.py::TestSystemHealth -v
```

### Performance Tests

```bash
cd backend
pytest tests/test_performance_load.py::TestResponseTimes::test_health_endpoint_response_time -v
```

## Quick Rollback

### Backend

```bash
PREV_TASK=$(aws ecs describe-services --cluster cms-cluster --services cms-service \
  --query 'services[0].deployments[1].taskDefinition' --output text)
aws ecs update-service --cluster cms-cluster --service cms-service \
  --task-definition ${PREV_TASK} --force-new-deployment
```

### Frontend

```bash
# Restore from S3 version
aws s3api list-object-versions --bucket ${S3_BUCKET} --prefix index.html
aws s3api copy-object --bucket ${S3_BUCKET} \
  --copy-source ${S3_BUCKET}/index.html?versionId=${VERSION_ID} --key index.html
aws cloudfront create-invalidation --distribution-id ${CF_ID} --paths "/*"
```

### Database

```bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier cms-db-restored \
  --db-snapshot-identifier ${SNAPSHOT_ID}
```

## Quick Monitoring

### View Logs

```bash
# AgentCore logs
agentcore logs --runtime content-marketing-swarm --tail 100 --follow

# ECS logs
aws logs tail /ecs/content-marketing-swarm --follow

# RDS logs
aws rds describe-db-log-files --db-instance-identifier cms-db
```

### Check Metrics

```bash
# Dashboard
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=cms-production"

# Alarms
aws cloudwatch describe-alarms --alarm-name-prefix "content-marketing-swarm"

# Service status
aws ecs describe-services --cluster cms-cluster --services cms-service
```

### Test Alerts

```bash
aws sns publish --topic-arn ${TOPIC_ARN} \
  --subject "Test Alert" \
  --message "Testing alert system"
```

## Quick Troubleshooting

### ECS Tasks Not Starting

```bash
aws ecs describe-tasks --cluster cms-cluster --tasks ${TASK_ARN}
aws logs tail /ecs/content-marketing-swarm --follow
```

### Database Connection Issues

```bash
aws rds describe-db-instances --db-instance-identifier cms-db
aws ec2 describe-security-groups --group-ids ${SG_ID}
```

### High Latency

```bash
aws cloudwatch get-metric-statistics --namespace AWS/ECS \
  --metric-name CPUUtilization --dimensions Name=ServiceName,Value=cms-service \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) --period 300 --statistics Average
```

### Agent Issues

```bash
agentcore logs --runtime content-marketing-swarm --tail 100
agentcore describe --runtime content-marketing-swarm
agentcore status --runtime content-marketing-swarm
```

## Important URLs

```bash
# Get from Terraform outputs
cd infrastructure/terraform/environments/prod

# Backend API
terraform output -raw alb_dns_name

# Frontend
terraform output -raw cloudfront_url

# Database
terraform output -raw rds_endpoint

# Dashboard
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards:name=cms-production"
```

## Emergency Contacts

- **DevOps Team:** adelanaj@amazon.co.uk
- **On-Call:** PagerDuty / Slack #oncall
- **AWS Support:** AWS Console > Support
- **Documentation:** See DEPLOYMENT_GUIDE.md

## Key Metrics

| Metric | Target | Alert Threshold |
|--------|--------|-----------------|
| Success Rate | >95% | <90% |
| P95 Response Time | <3s | >5s |
| Error Rate | <2% | >5% |
| CPU Utilization | <70% | >80% |
| Memory Utilization | <70% | >80% |

## Deployment Timeline

| Phase | Duration | Can Rollback |
|-------|----------|--------------|
| Infrastructure | 15-20 min | Yes (Terraform) |
| Database | 1-2 min | Yes (Snapshot) |
| Backend | 5-10 min | Yes (ECS) |
| Frontend | 5-10 min | Yes (S3 versions) |
| Agents | 5-10 min | Yes (AgentCore) |
| Monitoring | 2-3 min | N/A |
| **Total** | **30-45 min** | - |

## Post-Deployment

```bash
# 1. Verify all services
aws ecs describe-services --cluster cms-cluster --services cms-service
aws rds describe-db-instances --db-instance-identifier cms-db
agentcore status --runtime content-marketing-swarm

# 2. Run smoke tests
curl http://${ALB_DNS}/health
pytest tests/test_e2e_staging.py::TestSystemHealth -v

# 3. Monitor for 30 minutes
watch -n 60 'aws cloudwatch get-metric-statistics ...'

# 4. Notify stakeholders
echo "Deployment complete. Monitoring for issues."
```

---

**For detailed instructions, see:** [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
