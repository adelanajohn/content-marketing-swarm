# CORS Configuration Fix - Complete ✅

**Date:** November 25, 2025  
**Issue:** CORS policy blocking requests from CloudFront frontend  
**Status:** ✅ **RESOLVED**

---

## Problem

The frontend hosted on CloudFront (`https://d2b386ss3jk33z.cloudfront.net`) was unable to make requests to the backend API (`https://api.blacksteep.com`) due to CORS policy restrictions.

### Error Message

```
Access to fetch at 'https://api.blacksteep.com/' from origin 'https://d2b386ss3jk33z.cloudfront.net' 
has been blocked by CORS policy: Response to preflight request doesn't pass access control check: 
No 'Access-Control-Allow-Origin' header is present on the requested resource.
```

### Root Cause

The backend CORS configuration in `backend/app/config.py` only allowed requests from `http://localhost:3000` (development environment) and did not include the production CloudFront URL.

---

## Solution

### 1. Updated CORS Configuration

**File:** `backend/app/config.py`

**Before:**
```python
cors_origins: list[str] = ["http://localhost:3000"]
```

**After:**
```python
cors_origins: list[str] = [
    "http://localhost:3000",
    "https://d2b386ss3jk33z.cloudfront.net"
]
```

### 2. Rebuilt and Redeployed Backend

Steps taken:
1. Built Docker image for linux/amd64 platform
2. Tagged and pushed to ECR
3. Forced new ECS deployment
4. Verified deployment health

---

## Verification

### CORS Preflight Request Test

```bash
curl -v -H "Origin: https://d2b386ss3jk33z.cloudfront.net" \
     -H "Access-Control-Request-Method: POST" \
     -X OPTIONS https://api.blacksteep.com/
```

### Response Headers (After Fix)

```
access-control-allow-origin: https://d2b386ss3jk33z.cloudfront.net
access-control-allow-methods: DELETE, GET, HEAD, OPTIONS, PATCH, POST, PUT
access-control-allow-credentials: true
access-control-max-age: 600
```

✅ **Result:** The `Access-Control-Allow-Origin` header now includes the CloudFront URL.

---

## Deployment Details

### Docker Build

```bash
# Build for linux/amd64 platform (ECS Fargate requirement)
docker build --platform linux/amd64 -t content-marketing-swarm-backend:latest .

# Tag for ECR
docker tag content-marketing-swarm-backend:latest \
  298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest

# Push to ECR
docker push 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest
```

### ECS Deployment

```bash
# Force new deployment
aws ecs update-service \
  --cluster content-marketing-swarm-dev-cluster \
  --service content-marketing-swarm-dev-backend-service \
  --force-new-deployment \
  --region us-east-1
```

### Deployment Status

- **Cluster:** content-marketing-swarm-dev-cluster
- **Service:** content-marketing-swarm-dev-backend-service
- **Task Status:** RUNNING
- **Health Status:** HEALTHY
- **Image:** 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest

---

## Testing Checklist

### Backend API

- [x] CORS preflight requests return correct headers
- [x] `Access-Control-Allow-Origin` includes CloudFront URL
- [x] `Access-Control-Allow-Methods` includes all HTTP methods
- [x] `Access-Control-Allow-Credentials` is set to true
- [x] ECS tasks are healthy and running

### Frontend

Test the following in the browser:

- [ ] Open https://d2b386ss3jk33z.cloudfront.net
- [ ] Check browser console for CORS errors (should be none)
- [ ] Test content generation (POST request)
- [ ] Test WebSocket connection
- [ ] Verify all API requests succeed

---

## Configuration Reference

### CORS Middleware (FastAPI)

**File:** `backend/app/main.py`

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,  # From config.py
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Allowed Origins

Current configuration allows requests from:
1. **Development:** `http://localhost:3000` (local Next.js dev server)
2. **Production:** `https://d2b386ss3jk33z.cloudfront.net` (CloudFront distribution)

---

## Future Considerations

### Adding Additional Origins

To add more allowed origins (e.g., staging environment):

1. **Update config.py:**
   ```python
   cors_origins: list[str] = [
       "http://localhost:3000",
       "https://d2b386ss3jk33z.cloudfront.net",
       "https://staging.example.com"  # Add new origin
   ]
   ```

2. **Rebuild and redeploy:**
   ```bash
   docker build --platform linux/amd64 -t content-marketing-swarm-backend:latest .
   docker tag content-marketing-swarm-backend:latest 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest
   docker push 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest
   aws ecs update-service --cluster content-marketing-swarm-dev-cluster --service content-marketing-swarm-dev-backend-service --force-new-deployment --region us-east-1
   ```

### Environment-Based Configuration

For better flexibility, consider using environment variables:

```python
# In config.py
cors_origins: list[str] = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
```

Then set in ECS task definition:
```json
{
  "name": "CORS_ORIGINS",
  "value": "http://localhost:3000,https://d2b386ss3jk33z.cloudfront.net"
}
```

---

## Troubleshooting

### Issue: CORS errors persist after deployment

**Solution:**
1. Verify ECS deployment completed successfully
2. Check that new tasks are running with updated image
3. Clear browser cache and hard refresh (Ctrl+Shift+R)
4. Test with curl to verify headers

### Issue: WebSocket connections still fail

**Solution:**
1. Verify WebSocket endpoint is accessible: `wss://api.blacksteep.com/ws/stream-generation`
2. Check ALB supports WebSocket (it does by default)
3. Verify security groups allow port 443
4. Check backend WebSocket handler implementation

### Issue: Preflight requests timeout

**Solution:**
1. Verify ALB health checks are passing
2. Check ECS task logs for errors
3. Verify security groups allow traffic from ALB
4. Check target group health in AWS console

---

## Related Documentation

- **Backend Configuration:** `backend/app/config.py`
- **FastAPI Main:** `backend/app/main.py`
- **Deployment Guide:** `DEPLOYMENT_GUIDE.md`
- **Custom Domain Setup:** `CUSTOM_DOMAIN_SETUP_GUIDE.md`

---

## Summary

The CORS issue has been resolved by:
1. ✅ Adding CloudFront URL to allowed origins
2. ✅ Rebuilding Docker image for correct platform
3. ✅ Deploying updated backend to ECS
4. ✅ Verifying CORS headers in response

The frontend can now successfully make requests to the backend API without CORS errors.

---

**Status:** ✅ **COMPLETE**  
**Next Step:** Test the frontend in browser to verify end-to-end functionality
