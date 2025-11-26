# HTTPS Configuration Troubleshooting Guide

This guide provides detailed troubleshooting steps for common HTTPS configuration issues in the Content Marketing Swarm application.

## Table of Contents

1. [Certificate Validation Issues](#certificate-validation-issues)
2. [HTTPS Connection Problems](#https-connection-problems)
3. [Mixed Content Errors](#mixed-content-errors)
4. [WebSocket Connection Failures](#websocket-connection-failures)
5. [Certificate Expiration](#certificate-expiration)
6. [Performance Issues](#performance-issues)
7. [Security Group Configuration](#security-group-configuration)
8. [Frontend Configuration Issues](#frontend-configuration-issues)

## Quick Diagnostics

Run these commands to quickly diagnose HTTPS issues:

```bash
# Set environment variables
export AWS_REGION=us-east-1
cd infrastructure/terraform/environments/prod  # or dev

# Get ALB DNS name
export ALB_DNS=$(terraform output -raw alb_dns_name)

# Get certificate ARN
export CERT_ARN=$(terraform output -raw acm_certificate_arn)

# Test HTTPS endpoint
curl -v https://${ALB_DNS}/health

# Test HTTP redirect
curl -v http://${ALB_DNS}/health

# Check certificate status
aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.Status'

# Check security group rules
ALB_SG=$(terraform output -raw alb_security_group_id)
aws ec2 describe-security-groups \
  --group-ids ${ALB_SG} \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
```

## Certificate Validation Issues

### Issue: Certificate Stuck in "Pending Validation"

**Symptom:** ACM certificate remains in "Pending Validation" status for more than 30 minutes.

**Diagnosis:**

```bash
# Check certificate validation details
aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.DomainValidationOptions'

# Check certificate status
aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.{Status:Status,Domain:DomainName,ValidationMethod:ValidationMethod}'
```

**Root Causes:**

1. **DNS validation records not created:** For custom domains, DNS validation records must be added to Route 53
2. **Domain not accessible:** Domain must resolve correctly
3. **Validation method mismatch:** Email validation requires access to domain admin email
4. **AWS service delay:** DNS propagation can take time

**Solutions:**

1. **Wait longer (recommended first step):**
   - DNS validation typically takes 5-30 minutes
   - Can take up to 72 hours in rare cases
   - Check status every 5 minutes

2. **For ALB DNS names (automatic validation):**
   ```bash
   # Verify ALB is active
   aws elbv2 describe-load-balancers \
     --names content-marketing-swarm-${ENVIRONMENT}-alb \
     --query 'LoadBalancers[0].State'
   
   # Should return: {"Code": "active"}
   ```

3. **For custom domains (manual validation):**
   ```bash
   # Get validation records
   aws acm describe-certificate \
     --certificate-arn ${CERT_ARN} \
     --region ${AWS_REGION} \
     --query 'Certificate.DomainValidationOptions[0].ResourceRecord'
   
   # Add CNAME record to Route 53
   aws route53 change-resource-record-sets \
     --hosted-zone-id <ZONE_ID> \
     --change-batch file://validation-record.json
   ```

4. **Try email validation (alternative):**
   ```bash
   # Create new certificate with email validation
   aws acm request-certificate \
     --domain-name ${ALB_DNS} \
     --validation-method EMAIL \
     --region ${AWS_REGION}
   ```

5. **Contact AWS Support:**
   - If validation fails after 1 hour
   - Provide certificate ARN and domain name
   - Check AWS Service Health Dashboard

**Prevention:**
- Use ALB DNS name directly (automatic validation)
- Ensure DNS is properly configured before requesting certificate
- Test DNS resolution before certificate request

### Issue: Certificate Validation Failed

**Symptom:** Certificate status changes to "Failed" or "Validation Timed Out".

**Diagnosis:**

```bash
# Check failure reason
aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.{Status:Status,FailureReason:FailureReason}'
```

**Solutions:**

1. **Delete and recreate certificate:**
   ```bash
   # Delete failed certificate
   aws acm delete-certificate \
     --certificate-arn ${CERT_ARN} \
     --region ${AWS_REGION}
   
   # Recreate with Terraform
   cd infrastructure/terraform/environments/prod
   terraform apply -target=aws_acm_certificate.alb_cert
   ```

2. **Verify domain ownership:**
   - Ensure you own the domain
   - Check domain registration status
   - Verify domain is not expired

3. **Check domain accessibility:**
   ```bash
   # Test DNS resolution
   nslookup ${ALB_DNS}
   dig ${ALB_DNS}
   ```

## HTTPS Connection Problems

### Issue: HTTPS Requests Timeout

**Symptom:** HTTPS requests to ALB timeout or fail to connect.

**Diagnosis:**

```bash
# Test HTTPS connection
curl -v --connect-timeout 10 https://${ALB_DNS}/health

# Check listener configuration
aws elbv2 describe-listeners \
  --load-balancer-arn $(terraform output -raw alb_arn) \
  --query 'Listeners[?Port==`443`]'

# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(terraform output -raw target_group_arn)

# Check security group rules
aws ec2 describe-security-groups \
  --group-ids ${ALB_SG} \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
```

**Root Causes:**

1. **Security group not allowing port 443:** Most common issue
2. **Certificate not attached to listener:** Listener configuration error
3. **Target group unhealthy:** Backend ECS tasks not responding
4. **ALB not active:** ALB in provisioning or error state
5. **Network connectivity:** VPC or subnet configuration issue

**Solutions:**

1. **Fix security group (most common):**
   ```bash
   # Add ingress rule for port 443
   aws ec2 authorize-security-group-ingress \
     --group-id ${ALB_SG} \
     --protocol tcp \
     --port 443 \
     --cidr 0.0.0.0/0 \
     --region ${AWS_REGION}
   
   # Verify rule was added
   aws ec2 describe-security-groups \
     --group-ids ${ALB_SG} \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
   ```

2. **Verify certificate attachment:**
   ```bash
   # Check listener has certificate
   aws elbv2 describe-listeners \
     --load-balancer-arn $(terraform output -raw alb_arn) \
     --query 'Listeners[?Port==`443`].Certificates'
   
   # If missing, update listener
   aws elbv2 modify-listener \
     --listener-arn <LISTENER_ARN> \
     --certificates CertificateArn=${CERT_ARN}
   ```

3. **Check target health:**
   ```bash
   # View target health
   aws elbv2 describe-target-health \
     --target-group-arn $(terraform output -raw target_group_arn)
   
   # If unhealthy, check ECS tasks
   aws ecs list-tasks \
     --cluster content-marketing-swarm-cluster \
     --service-name content-marketing-swarm-service
   
   # Check task logs
   aws logs tail /ecs/content-marketing-swarm --follow
   ```

4. **Verify ALB state:**
   ```bash
   # Check ALB is active
   aws elbv2 describe-load-balancers \
     --names content-marketing-swarm-${ENVIRONMENT}-alb \
     --query 'LoadBalancers[0].{State:State,DNS:DNSName}'
   ```

5. **Test from different network:**
   - Try from different machine/network
   - Check if corporate firewall blocks port 443
   - Test with mobile hotspot

**Prevention:**
- Use Terraform to manage security groups
- Test HTTPS endpoint immediately after deployment
- Set up CloudWatch alarms for unhealthy targets

### Issue: SSL Handshake Failures

**Symptom:** SSL/TLS handshake fails with certificate errors.

**Diagnosis:**

```bash
# Test SSL handshake
openssl s_client -connect ${ALB_DNS}:443 -servername ${ALB_DNS}

# Check certificate details
openssl s_client -connect ${ALB_DNS}:443 -servername ${ALB_DNS} < /dev/null 2>/dev/null | openssl x509 -noout -text

# Test with curl
curl -v --insecure https://${ALB_DNS}/health
```

**Root Causes:**

1. **Certificate mismatch:** Certificate doesn't match domain
2. **Expired certificate:** Certificate has expired
3. **Untrusted certificate:** Certificate not from trusted CA
4. **Wrong SSL policy:** Incompatible cipher suites
5. **SNI issues:** Server Name Indication not configured

**Solutions:**

1. **Verify certificate matches domain:**
   ```bash
   # Check certificate subject
   openssl s_client -connect ${ALB_DNS}:443 -servername ${ALB_DNS} < /dev/null 2>/dev/null | openssl x509 -noout -subject
   
   # Should match ALB DNS name
   ```

2. **Check certificate expiration:**
   ```bash
   # Check expiration date
   aws acm describe-certificate \
     --certificate-arn ${CERT_ARN} \
     --region ${AWS_REGION} \
     --query 'Certificate.{NotBefore:NotBefore,NotAfter:NotAfter}'
   ```

3. **Verify SSL policy:**
   ```bash
   # Check listener SSL policy
   aws elbv2 describe-listeners \
     --load-balancer-arn $(terraform output -raw alb_arn) \
     --query 'Listeners[?Port==`443`].SslPolicy'
   
   # Should be: ELBSecurityPolicy-TLS13-1-2-2021-06
   ```

4. **Update SSL policy if needed:**
   ```bash
   aws elbv2 modify-listener \
     --listener-arn <LISTENER_ARN> \
     --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06
   ```

## Mixed Content Errors

### Issue: Browser Shows Mixed Content Warnings

**Symptom:** Browser console shows "Mixed Content" warnings despite HTTPS setup.

**Diagnosis:**

```bash
# Check frontend environment variables in deployed files
S3_BUCKET=$(terraform output -raw s3_frontend_bucket)
aws s3 cp s3://${S3_BUCKET}/_next/static/chunks/main-*.js - | grep -o 'http://[^"]*'

# Should return no results (all should be HTTPS)

# Check environment file
aws s3 cp s3://${S3_BUCKET}/.env.production - 2>/dev/null || echo "No .env.production in S3"

# Search for hardcoded HTTP URLs in code
cd frontend
grep -r "http://" components/ app/ --exclude-dir=node_modules
```

**Root Causes:**

1. **Environment variables use HTTP:** Most common issue
2. **Hardcoded HTTP URLs:** URLs hardcoded in code
3. **Frontend not rebuilt:** Old build with HTTP URLs
4. **CloudFront cache:** Cached files with HTTP URLs
5. **Third-party resources:** External HTTP resources

**Solutions:**

1. **Update environment variables:**
   ```bash
   cd frontend
   
   # Update .env.production
   cat > .env.production << EOF
   # Backend API URL (HTTPS)
   NEXT_PUBLIC_API_URL=https://${ALB_DNS}
   
   # WebSocket URL (WSS)
   NEXT_PUBLIC_WS_URL=wss://${ALB_DNS}/ws/stream-generation
   EOF
   
   # Verify
   cat .env.production
   ```

2. **Rebuild frontend:**
   ```bash
   cd frontend
   
   # Clean build
   rm -rf .next out node_modules/.cache
   
   # Install dependencies
   npm ci
   
   # Build with production env
   npm run build
   
   # Verify build uses HTTPS
   grep -r "http://" out/ --exclude-dir=node_modules | grep -v "https://"
   ```

3. **Redeploy to S3:**
   ```bash
   # Sync to S3
   aws s3 sync out/ s3://${S3_BUCKET}/ --delete --region ${AWS_REGION}
   
   # Verify uploaded files
   aws s3 ls s3://${S3_BUCKET}/ --recursive | head -20
   ```

4. **Invalidate CloudFront cache:**
   ```bash
   # Get CloudFront distribution ID
   CLOUDFRONT_ID=$(terraform output -raw cloudfront_distribution_id)
   
   # Create invalidation
   aws cloudfront create-invalidation \
     --distribution-id ${CLOUDFRONT_ID} \
     --paths "/*" \
     --region ${AWS_REGION}
   
   # Wait for invalidation to complete
   aws cloudfront wait invalidation-completed \
     --distribution-id ${CLOUDFRONT_ID} \
     --id <INVALIDATION_ID>
   ```

5. **Clear browser cache:**
   - Hard refresh: Ctrl+Shift+R (Windows/Linux) or Cmd+Shift+R (Mac)
   - Clear browser cache completely
   - Test in incognito/private mode

6. **Fix hardcoded URLs:**
   ```bash
   # Find hardcoded HTTP URLs
   cd frontend
   grep -rn "http://" components/ app/ lib/ --exclude-dir=node_modules
   
   # Replace with environment variables
   # Example: Replace "http://api.example.com" with process.env.NEXT_PUBLIC_API_URL
   ```

**Prevention:**
- Always use environment variables for URLs
- Never hardcode HTTP URLs in code
- Test in incognito mode after deployment
- Set up automated tests for mixed content

### Issue: API Calls Still Use HTTP

**Symptom:** Network tab shows API calls using HTTP instead of HTTPS.

**Diagnosis:**

```bash
# Check API client configuration
cd frontend
grep -r "NEXT_PUBLIC_API_URL" components/ app/ lib/

# Check if environment variables are loaded
grep -r "process.env.NEXT_PUBLIC" components/ app/ lib/

# Verify build-time environment
cd out
grep -r "http://" _next/static/chunks/ | grep -v "https://"
```

**Solutions:**

1. **Verify environment variable usage:**
   ```typescript
   // Correct usage in frontend code
   const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://default-url.com';
   
   // Make API call
   fetch(`${API_URL}/api/endpoint`);
   ```

2. **Check Next.js configuration:**
   ```javascript
   // next.config.js
   module.exports = {
     env: {
       NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
       NEXT_PUBLIC_WS_URL: process.env.NEXT_PUBLIC_WS_URL,
     },
   };
   ```

3. **Rebuild and redeploy:**
   ```bash
   cd frontend
   npm run build
   aws s3 sync out/ s3://${S3_BUCKET}/ --delete
   aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths "/*"
   ```

## WebSocket Connection Failures

### Issue: WebSocket Connections Fail Over WSS

**Symptom:** WebSocket connections fail to establish or immediately disconnect.

**Diagnosis:**

```bash
# Test WebSocket endpoint with wscat
npm install -g wscat
wscat -c wss://${ALB_DNS}/ws/stream-generation

# Check ALB access logs for WebSocket upgrade requests
aws logs tail /aws/elasticloadbalancing/app/content-marketing-swarm-${ENVIRONMENT}-alb --follow

# Check backend WebSocket handler logs
aws logs tail /ecs/content-marketing-swarm --follow --filter-pattern "websocket"
```

**Root Causes:**

1. **Frontend uses WS instead of WSS:** Protocol mismatch
2. **Backend doesn't accept WebSocket:** Handler not configured
3. **ALB timeout too short:** Connection times out
4. **Security group blocks traffic:** Port 443 not open
5. **CORS issues:** Cross-origin WebSocket blocked

**Solutions:**

1. **Verify WSS protocol:**
   ```bash
   # Check frontend WebSocket URL
   cd frontend
   grep -r "NEXT_PUBLIC_WS_URL" components/ hooks/
   
   # Should use wss:// not ws://
   ```

2. **Update WebSocket URL:**
   ```bash
   # Update .env.production
   echo "NEXT_PUBLIC_WS_URL=wss://${ALB_DNS}/ws/stream-generation" >> frontend/.env.production
   
   # Rebuild
   cd frontend
   npm run build
   aws s3 sync out/ s3://${S3_BUCKET}/ --delete
   ```

3. **Test WebSocket with wscat:**
   ```bash
   # Install wscat
   npm install -g wscat
   
   # Test connection
   wscat -c wss://${ALB_DNS}/ws/stream-generation
   
   # Should connect successfully
   # Type messages to test bidirectional communication
   ```

4. **Check ALB idle timeout:**
   ```bash
   # Check current timeout
   aws elbv2 describe-load-balancer-attributes \
     --load-balancer-arn $(terraform output -raw alb_arn) \
     --query 'Attributes[?Key==`idle_timeout.timeout_seconds`]'
   
   # Increase if needed (default is 60 seconds)
   aws elbv2 modify-load-balancer-attributes \
     --load-balancer-arn $(terraform output -raw alb_arn) \
     --attributes Key=idle_timeout.timeout_seconds,Value=300
   ```

5. **Verify backend WebSocket handler:**
   ```bash
   # Check backend logs for WebSocket connections
   aws logs tail /ecs/content-marketing-swarm --follow --filter-pattern "websocket"
   
   # Test WebSocket endpoint directly
   curl -i -N \
     -H "Connection: Upgrade" \
     -H "Upgrade: websocket" \
     -H "Sec-WebSocket-Version: 13" \
     -H "Sec-WebSocket-Key: test" \
     https://${ALB_DNS}/ws/stream-generation
   ```

**Prevention:**
- Always use WSS for WebSocket over HTTPS
- Test WebSocket connections after HTTPS setup
- Monitor WebSocket connection metrics
- Set appropriate ALB idle timeout

## Certificate Expiration

### Issue: Certificate Approaching Expiration

**Symptom:** Certificate will expire soon or has expired.

**Diagnosis:**

```bash
# Check certificate expiration
aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.{NotAfter:NotAfter,DaysUntilExpiry:NotAfter}'

# Check renewal status
aws acm describe-certificate \
  --certificate-arn ${CERT_ARN} \
  --region ${AWS_REGION} \
  --query 'Certificate.RenewalSummary'

# Calculate days until expiration
openssl s_client -connect ${ALB_DNS}:443 -servername ${ALB_DNS} < /dev/null 2>/dev/null | openssl x509 -noout -enddate
```

**Root Causes:**

1. **Automatic renewal failed:** DNS validation records removed
2. **Domain no longer accessible:** Domain expired or DNS changed
3. **ACM service issue:** Rare AWS service issue
4. **Certificate not managed by ACM:** Manual certificate

**Solutions:**

1. **ACM automatic renewal (default):**
   - ACM automatically renews certificates 60 days before expiration
   - No action required if domain validation is still valid
   - Monitor renewal status in ACM console

2. **Check renewal status:**
   ```bash
   # View renewal details
   aws acm describe-certificate \
     --certificate-arn ${CERT_ARN} \
     --region ${AWS_REGION} \
     --query 'Certificate.RenewalSummary'
   ```

3. **Verify domain validation:**
   ```bash
   # Check validation records still exist
   aws acm describe-certificate \
     --certificate-arn ${CERT_ARN} \
     --region ${AWS_REGION} \
     --query 'Certificate.DomainValidationOptions'
   
   # Verify DNS records
   nslookup ${ALB_DNS}
   ```

4. **Manual renewal (if automatic fails):**
   ```bash
   # Request new certificate
   cd infrastructure/terraform/environments/prod
   
   # Update certificate resource (forces recreation)
   terraform taint aws_acm_certificate.alb_cert
   terraform apply
   ```

5. **Set up expiration alerts:**
   ```bash
   # Create CloudWatch alarm for certificate expiration
   aws cloudwatch put-metric-alarm \
     --alarm-name certificate-expiration-warning \
     --alarm-description "Certificate expires in 30 days" \
     --metric-name DaysToExpiry \
     --namespace AWS/CertificateManager \
     --statistic Minimum \
     --period 86400 \
     --evaluation-periods 1 \
     --threshold 30 \
     --comparison-operator LessThanThreshold \
     --dimensions Name=CertificateArn,Value=${CERT_ARN}
   ```

**Prevention:**
- ACM handles renewal automatically
- Keep domain validation records in place
- Monitor certificate expiration in CloudWatch
- Set up alerts for expiration warnings

## Performance Issues

### Issue: High TLS Handshake Latency

**Symptom:** HTTPS requests have high latency compared to HTTP.

**Diagnosis:**

```bash
# Measure TLS handshake time
curl -w "@curl-format.txt" -o /dev/null -s https://${ALB_DNS}/health

# Create curl-format.txt
cat > curl-format.txt << EOF
    time_namelookup:  %{time_namelookup}s\n
       time_connect:  %{time_connect}s\n
    time_appconnect:  %{time_appconnect}s\n
      time_redirect:  %{time_redirect}s\n
   time_pretransfer:  %{time_pretransfer}s\n
 time_starttransfer:  %{time_starttransfer}s\n
                    ----------\n
         time_total:  %{time_total}s\n
EOF

# Check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name TargetResponseTime \
  --dimensions Name=LoadBalancer,Value=app/content-marketing-swarm-${ENVIRONMENT}-alb/* \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Average,Maximum
```

**Solutions:**

1. **Enable HTTP/2 (enabled by default on ALB):**
   - HTTP/2 reduces TLS overhead
   - Multiplexes multiple requests over single connection
   - Already enabled on ALB

2. **Use connection keep-alive:**
   ```python
   # Backend: Enable keep-alive
   import uvicorn
   
   uvicorn.run(
       app,
       host="0.0.0.0",
       port=8000,
       keep_alive_timeout=75  # Longer than ALB timeout
   )
   ```

3. **Implement connection pooling:**
   ```typescript
   // Frontend: Use connection pooling
   const agent = new https.Agent({
     keepAlive: true,
     maxSockets: 50,
   });
   
   fetch(url, { agent });
   ```

4. **Optimize SSL policy:**
   ```bash
   # Use TLS 1.3 only for better performance
   aws elbv2 modify-listener \
     --listener-arn <LISTENER_ARN> \
     --ssl-policy ELBSecurityPolicy-TLS13-1-3-2021-06
   ```

5. **Monitor and optimize:**
   - Monitor TLS handshake time in CloudWatch
   - Set up alerts for high latency
   - Consider CloudFront for caching

## Security Group Configuration

### Issue: Security Group Not Allowing HTTPS Traffic

**Symptom:** HTTPS requests timeout or connection refused.

**Diagnosis:**

```bash
# Check security group rules
ALB_SG=$(terraform output -raw alb_security_group_id)
aws ec2 describe-security-groups \
  --group-ids ${ALB_SG} \
  --query 'SecurityGroups[0].IpPermissions'

# Check for port 443 rule
aws ec2 describe-security-groups \
  --group-ids ${ALB_SG} \
  --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
```

**Solutions:**

1. **Add HTTPS ingress rule:**
   ```bash
   # Add rule for port 443
   aws ec2 authorize-security-group-ingress \
     --group-id ${ALB_SG} \
     --protocol tcp \
     --port 443 \
     --cidr 0.0.0.0/0 \
     --region ${AWS_REGION}
   ```

2. **Verify rule was added:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids ${ALB_SG} \
     --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]'
   ```

3. **Use Terraform (recommended):**
   ```bash
   cd infrastructure/terraform/environments/prod
   terraform apply -target=aws_security_group_rule.alb_https_ingress
   ```

## Frontend Configuration Issues

### Issue: Environment Variables Not Loaded

**Symptom:** Frontend uses default URLs instead of configured HTTPS URLs.

**Diagnosis:**

```bash
# Check environment file
cd frontend
cat .env.production

# Check if variables are used in code
grep -r "NEXT_PUBLIC_API_URL" components/ app/ lib/

# Check build output
grep -r "NEXT_PUBLIC" out/_next/static/chunks/ | head -5
```

**Solutions:**

1. **Verify environment file exists:**
   ```bash
   cd frontend
   ls -la .env.production
   
   # If missing, create it
   cat > .env.production << EOF
   NEXT_PUBLIC_API_URL=https://${ALB_DNS}
   NEXT_PUBLIC_WS_URL=wss://${ALB_DNS}/ws/stream-generation
   EOF
   ```

2. **Rebuild with environment variables:**
   ```bash
   cd frontend
   
   # Clean build
   rm -rf .next out
   
   # Build with production env
   npm run build
   
   # Verify variables in build
   grep -r "https://${ALB_DNS}" out/
   ```

3. **Check Next.js configuration:**
   ```javascript
   // next.config.js
   module.exports = {
     env: {
       NEXT_PUBLIC_API_URL: process.env.NEXT_PUBLIC_API_URL,
       NEXT_PUBLIC_WS_URL: process.env.NEXT_PUBLIC_WS_URL,
     },
   };
   ```

4. **Redeploy:**
   ```bash
   aws s3 sync out/ s3://${S3_BUCKET}/ --delete
   aws cloudfront create-invalidation --distribution-id ${CLOUDFRONT_ID} --paths "/*"
   ```

## Getting Help

If issues persist after following this guide:

1. **Check AWS Service Health Dashboard:**
   - https://status.aws.amazon.com/
   - Look for issues with ACM, ALB, or ECS

2. **Review CloudWatch Logs:**
   ```bash
   # ALB access logs
   aws logs tail /aws/elasticloadbalancing/app/content-marketing-swarm-${ENVIRONMENT}-alb --follow
   
   # ECS task logs
   aws logs tail /ecs/content-marketing-swarm --follow
   
   # Application logs
   aws logs tail /agentcore/content-marketing-swarm --follow
   ```

3. **Run Property-Based Tests:**
   ```bash
   cd backend
   pytest tests/test_property_https_listener.py -v
   pytest tests/test_property_http_redirect.py -v
   pytest tests/test_property_certificate_validity.py -v
   
   cd ../frontend
   npm test -- __tests__/test_property_frontend_deployment.test.tsx
   ```

4. **Contact AWS Support:**
   - Open support case in AWS Console
   - Provide certificate ARN, ALB ARN, and error details
   - Include CloudWatch logs and diagnostics output

5. **Review Documentation:**
   - Infrastructure README: `infrastructure/terraform/README.md`
   - Deployment Guide: `DEPLOYMENT_GUIDE.md`
   - HTTPS Setup Spec: `.kiro/specs/https-alb-setup/`

## Related Documentation

- **Infrastructure README:** `infrastructure/terraform/README.md`
- **Deployment Guide:** `DEPLOYMENT_GUIDE.md`
- **HTTPS Setup Spec:** `.kiro/specs/https-alb-setup/`
- **Domain Strategy:** `.kiro/specs/https-alb-setup/DOMAIN_STRATEGY.md`
- **Quick Reference:** `.kiro/specs/https-alb-setup/QUICK_REFERENCE.md`

---

**Last Updated:** 2025-11-25
**Version:** 1.0.0
**Maintained By:** DevOps Team
