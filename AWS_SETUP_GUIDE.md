# AWS Infrastructure Setup - Content Marketing Swarm

## Quick Prerequisites Check

```bash
# 1. Check tools
aws --version          # Need: aws-cli/2.x+
terraform --version    # Need: v1.0+
docker --version       # Need: 20.x+
node --version         # Need: v18+
agentcore --help       # Should show commands

# 2. Set environment
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# 3. Verify AWS access
aws sts get-caller-identity
```

## Step-by-Step Setup

### 1. Enable Bedrock Models

```bash
# Request model access (manual step)
echo "Visit: https://console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess"
echo "Enable: anthropic.claude-3-7-sonnet-20250219-v1:0"
echo "Enable: amazon.nova-canvas-v1:0"
```

### 2. Deploy Infrastructure with Terraform

```bash
cd infrastructure/terraform/environments/dev

# Create variables file
cat > terraform.tfvars <<EOF
project_name = "content-marketing-swarm"
environment  = "dev"
aws_region   = "${AWS_REGION}"
alert_email  = "adelanaj@amazon.co.uk"
EOF

# Deploy
terraform init
terraform plan
terraform apply

# Save outputs
terraform output > ../../../outputs.txt
```

**Time:** 15-20 minutes

**Creates:**
- VPC with subnets
- RDS PostgreSQL
- ECS Fargate cluster
- S3 buckets
- CloudFront CDN
- IAM roles
- CloudWatch monitoring

### 3. Setup Database

```bash
cd backend

# Get credentials from Terraform
export DB_ENDPOINT=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw rds_endpoint)
export DB_PASSWORD=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw rds_password)
export DATABASE_URL="postgresql://dbadmin:${DB_PASSWORD}@${DB_ENDPOINT}/contentmarketing"

# Run migrations
alembic upgrade head
```

### 4. Deploy Backend

```bash
cd backend

# Create ECR repo
aws ecr create-repository --repository-name cms-backend --region ${AWS_REGION}

# Build and push
docker build -t cms-backend:latest .
docker tag cms-backend:latest ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/cms-backend:latest
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/cms-backend:latest

# Deploy to ECS
export ECS_CLUSTER=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw ecs_cluster_name)
export ECS_SERVICE=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw ecs_service_name)
aws ecs update-service --cluster ${ECS_CLUSTER} --service ${ECS_SERVICE} --force-new-deployment --region ${AWS_REGION}
```

### 5. Deploy Frontend

```bash
cd frontend

npm ci
npm run build

export S3_BUCKET=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw s3_frontend_bucket)
aws s3 sync out/ s3://${S3_BUCKET}/ --delete

export CF_DIST=$(cd ../infrastructure/terraform/environments/dev && terraform output -raw cloudfront_distribution_id)
aws cloudfront create-invalidation --distribution-id ${CF_DIST} --paths "/*"
```

### 6. Setup AgentCore

```bash
cd backend

# Run setup scripts
python scripts/setup_gateway.py
./scripts/deploy_to_agentcore.sh
```

### 7. Verify Deployment

```bash
export ALB_DNS=$(cd infrastructure/terraform/environments/dev && terraform output -raw alb_dns_name)

# Test
curl http://${ALB_DNS}/health
# Expected: {"status":"healthy"}

echo "Backend: http://${ALB_DNS}"
echo "Frontend: $(cd infrastructure/terraform/environments/dev && terraform output -raw cloudfront_url)"
```

## Quick Test

```bash
# Test content generation
curl -X POST http://${ALB_DNS}/api/generate-content \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Test post","user_id":"test","platforms":["linkedin"]}'
```

## Monitoring

```bash
# View logs
aws logs tail /ecs/content-marketing-swarm --follow

# Dashboard
echo "https://console.aws.amazon.com/cloudwatch/home?region=${AWS_REGION}#dashboards"
```

## Cost Estimate

**Dev Environment:** ~$130-150/month
- ECS: $50
- RDS: $60
- S3/CDN: $10
- Other: $20

## Cleanup

```bash
cd infrastructure/terraform/environments/dev
terraform destroy
```

## Troubleshooting

**ECS tasks not starting:**
```bash
aws ecs describe-tasks --cluster ${ECS_CLUSTER} --tasks <TASK_ARN>
aws logs tail /ecs/content-marketing-swarm --follow
```

**Database connection fails:**
```bash
aws rds describe-db-instances --db-instance-identifier <DB_ID>
```

## Full Documentation

- Detailed guide: `DEPLOYMENT_GUIDE.md`
- Quick reference: `QUICK_DEPLOYMENT_REFERENCE.md`
- Terraform docs: `infrastructure/terraform/README.md`

---

**Total Setup Time:** 45-60 minutes
