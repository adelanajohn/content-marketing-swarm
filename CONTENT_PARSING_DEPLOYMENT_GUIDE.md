# Content Output Parsing Feature - Deployment Guide

## Overview

This guide covers deploying the content output parsing feature to production. The feature has been fully implemented and tested locally.

## What Was Implemented

### Backend Changes
1. **Content Parser Module** (`backend/app/parsers/content_parser.py`)
   - Parses agent outputs to extract structured content items
   - Extracts hashtags, metadata, and media URLs
   - Handles multiple output formats (JSON and natural language)
   - Error-resilient parsing

2. **Enhanced WebSocket Handler** (`backend/app/api/websocket.py`)
   - Integrated ContentParser
   - Saves parsed content items to database
   - Streams content items to frontend via WebSocket
   - Tracks and reports accurate completion counts

3. **Database Integration**
   - Content items saved with all required fields
   - Status automatically set to "draft"
   - Metadata includes word count, character count, and timestamps

### Frontend Changes
1. **WebSocket Message Handling** (`frontend/app/page.tsx`)
   - Handles "content_generated" message type
   - Adds content items to state incrementally
   - Displays completion messages with counts

2. **Content Display** (`frontend/components/ContentPreview.tsx`)
   - Already configured to display content items
   - Preserves display order
   - Shows platform-specific formatting

### Tests
- 12 property-based tests covering all correctness properties
- 7 integration tests verifying end-to-end flow
- All tests passing locally

## Deployment Steps

### Prerequisites
- AWS CLI configured with appropriate credentials
- Docker installed
- Access to ECS cluster and ECR repository
- Access to S3 bucket and CloudFront distribution

### Step 1: Deploy Backend Changes

The backend changes are already in the codebase. To deploy:

```bash
cd backend

# Build Docker image
docker build -t content-marketing-swarm-backend:latest .

# Tag for ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/content-marketing-swarm-backend"

docker tag content-marketing-swarm-backend:latest ${ECR_REPO}:latest
docker tag content-marketing-swarm-backend:latest ${ECR_REPO}:$(date +%Y%m%d-%H%M%S)

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
    docker login --username AWS --password-stdin ${ECR_REPO}

# Push to ECR
docker push ${ECR_REPO}:latest
docker push ${ECR_REPO}:$(date +%Y%m%d-%H%M%S)

# Update ECS service
aws ecs update-service \
    --cluster content-marketing-swarm-cluster \
    --service content-marketing-swarm-service \
    --force-new-deployment \
    --region ${AWS_REGION}
```

### Step 2: Verify Backend Deployment

Wait for ECS service to stabilize (5-10 minutes), then check:

```bash
# Check ECS service status
aws ecs describe-services \
    --cluster content-marketing-swarm-cluster \
    --services content-marketing-swarm-service \
    --region ${AWS_REGION}

# Check task health
aws ecs list-tasks \
    --cluster content-marketing-swarm-cluster \
    --service-name content-marketing-swarm-service \
    --region ${AWS_REGION}

# Test health endpoint
ALB_DNS=$(aws elbv2 describe-load-balancers \
    --query 'LoadBalancers[0].DNSName' \
    --output text \
    --region ${AWS_REGION})

curl http://${ALB_DNS}/health
```

### Step 3: Deploy Frontend Changes

```bash
cd frontend

# Install dependencies
npm ci

# Build Next.js app
npm run build

# Get S3 bucket and CloudFront distribution
S3_BUCKET=$(aws s3 ls | grep content-marketing | awk '{print $3}')
CF_DIST_ID=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[?Comment=='Content Marketing Swarm'].Id" \
    --output text)

# Sync to S3
aws s3 sync out/ s3://${S3_BUCKET}/ --delete --region ${AWS_REGION}

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
    --distribution-id ${CF_DIST_ID} \
    --paths "/*"
```

### Step 4: End-to-End Testing in Production

1. **Access the Production UI**
   ```bash
   # Get CloudFront URL
   CF_URL=$(aws cloudfront list-distributions \
       --query "DistributionList.Items[?Comment=='Content Marketing Swarm'].DomainName" \
       --output text)
   
   echo "Frontend URL: https://${CF_URL}"
   ```

2. **Generate Content**
   - Navigate to the production UI
   - Create or select a brand profile
   - Submit a content generation request
   - Example: "Create 3 LinkedIn posts about our new AI feature"

3. **Verify Content Display**
   - Content items should appear in real-time as they're generated
   - Each item should show:
     - Platform (LinkedIn, Twitter, etc.)
     - Content text
     - Hashtags
     - Status (draft)
   - Completion message should show accurate count

4. **Check Database Records**
   ```bash
   # Connect to RDS (requires bastion host or VPN)
   psql -h <RDS_ENDPOINT> -U <DB_USER> -d contentmarketing
   
   # Query content items
   SELECT id, platform, status, created_at, hashtags 
   FROM content_items 
   ORDER BY created_at DESC 
   LIMIT 10;
   ```

5. **Verify WebSocket Messages**
   - Open browser developer tools (Network tab)
   - Filter for WebSocket connections
   - Generate content and observe messages:
     - `content_generated` messages for each item
     - `complete` message with accurate count

## Verification Checklist

- [ ] Backend Docker image built and pushed to ECR
- [ ] ECS service updated and running new tasks
- [ ] Health endpoint returns 200 OK
- [ ] Frontend built and synced to S3
- [ ] CloudFront cache invalidated
- [ ] Can access production UI
- [ ] Content generation request completes successfully
- [ ] Content items appear in UI in real-time
- [ ] All content items have required fields (platform, content, hashtags, status)
- [ ] Status is set to "draft" for new items
- [ ] Completion message shows correct count
- [ ] Database contains generated content items
- [ ] WebSocket messages are sent correctly

## Rollback Plan

If issues are encountered:

1. **Rollback Backend**
   ```bash
   # Get previous task definition
   PREV_TASK_DEF=$(aws ecs describe-services \
       --cluster content-marketing-swarm-cluster \
       --services content-marketing-swarm-service \
       --query 'services[0].deployments[1].taskDefinition' \
       --output text)
   
   # Update service to previous version
   aws ecs update-service \
       --cluster content-marketing-swarm-cluster \
       --service content-marketing-swarm-service \
       --task-definition ${PREV_TASK_DEF}
   ```

2. **Rollback Frontend**
   ```bash
   # Restore from S3 versioning
   aws s3api list-object-versions \
       --bucket ${S3_BUCKET} \
       --prefix index.html
   
   # Restore specific version
   aws s3api copy-object \
       --bucket ${S3_BUCKET} \
       --copy-source ${S3_BUCKET}/index.html?versionId=<VERSION_ID> \
       --key index.html
   
   # Invalidate cache
   aws cloudfront create-invalidation \
       --distribution-id ${CF_DIST_ID} \
       --paths "/*"
   ```

## Monitoring

After deployment, monitor:

1. **CloudWatch Logs**
   - Log group: `/aws/content-marketing-swarm`
   - Look for parsing errors or WebSocket issues

2. **ECS Service Metrics**
   - CPU and memory utilization
   - Task count and health

3. **Application Metrics**
   - Content generation success rate
   - Parsing success rate
   - WebSocket connection stability

4. **Database**
   - Content item creation rate
   - Query performance

## Troubleshooting

### Content Not Appearing in UI
- Check browser console for WebSocket errors
- Verify WebSocket connection is established
- Check backend logs for parsing errors
- Verify database connectivity

### Parsing Errors
- Check CloudWatch logs for parser exceptions
- Verify agent output format
- Test parser with sample outputs locally

### Database Issues
- Verify RDS connectivity
- Check database credentials
- Verify content_items table exists
- Check for constraint violations

## Notes

- All code changes are backward compatible
- No database migrations required (content_items table already exists)
- Feature can be disabled by reverting WebSocket handler changes
- Parser is error-resilient and won't crash on malformed input

## Success Criteria

Deployment is successful when:
1. Users can generate content via the UI
2. Content items appear in real-time during generation
3. All content items are saved to database with correct fields
4. Completion message shows accurate count
5. No errors in CloudWatch logs
6. WebSocket connections are stable
