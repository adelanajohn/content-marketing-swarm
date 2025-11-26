#!/bin/bash
set -e

echo "🏗️  Building frontend..."
cd frontend
npm run build

echo "📦 Syncing to S3..."
aws s3 sync out/ s3://content-marketing-swarm-dev-frontend/ --delete --exclude "*.txt"

echo "🔄 Invalidating CloudFront cache..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
  --distribution-id EOKK53AQTTMGG \
  --paths "/*" \
  --query 'Invalidation.Id' \
  --output text)

echo "✅ Deployment complete!"
echo "📊 Invalidation ID: $INVALIDATION_ID"
echo "🌐 URL: https://d2b386ss3jk33z.cloudfront.net"
echo ""
echo "⏳ Waiting for cache invalidation (1-2 minutes)..."
echo "   Check status: aws cloudfront get-invalidation --distribution-id EOKK53AQTTMGG --id $INVALIDATION_ID"
