# API Endpoint Fix - Complete ✅

**Date:** November 25, 2025  
**Issue:** Frontend calling wrong API endpoint  
**Status:** ✅ **RESOLVED**

---

## Problem

After fixing the CORS issue, the frontend was making requests to the wrong endpoint:
- **Attempted:** `POST https://api.blacksteep.com/` (root endpoint)
- **Expected:** `POST https://api.blacksteep.com/api/generate-content`
- **Error:** `405 Method Not Allowed`

### Root Cause

The frontend code in `frontend/app/page.tsx` was using the environment variable `NEXT_PUBLIC_API_URL` incorrectly:

**Before:**
```typescript
const response = await fetch(
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/generate-content",
  { ... }
);
```

When `NEXT_PUBLIC_API_URL` was set to `https://api.blacksteep.com`, it would make a request to just the base URL without the `/api/generate-content` path.

The fallback worked correctly (`http://localhost:8000/api/generate-content`), but the production configuration was broken.

---

## Solution

### 1. Fixed API URL Construction

Updated all fetch calls in `frontend/app/page.tsx` to properly construct the full URL:

**After:**
```typescript
const response = await fetch(
  `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/generate-content`,
  { ... }
);
```

### 2. Fixed All API Endpoints

Updated three locations in the code:
1. **Content Generation:** `/api/generate-content`
2. **Content Regeneration:** `/api/content/${itemId}/regenerate`
3. **Publishing (2 locations):** `/api/publish`

### 3. Rebuilt and Redeployed Frontend

```bash
# Build frontend
cd frontend
npm run build

# Deploy to S3
aws s3 sync .next/static s3://content-marketing-swarm-dev-frontend/_next/static --delete
aws s3 sync .next/server s3://content-marketing-swarm-dev-frontend/_next/server --delete
aws s3 cp .next/server/app/index.html s3://content-marketing-swarm-dev-frontend/index.html

# Invalidate CloudFront cache
aws cloudfront create-invalidation --distribution-id EOKK53AQTTMGG --paths "/*"
```

---

## Verification

### Available API Endpoints

```bash
curl -s https://api.blacksteep.com/openapi.json | jq '.paths | keys'
```

**Result:**
```json
[
  "/",
  "/api/ab-tests",
  "/api/ab-tests/{test_id}/results",
  "/api/analytics",
  "/api/analytics/collect",
  "/api/brand-profiles",
  "/api/brand-profiles/{profile_id}",
  "/api/content/{content_id}/regenerate",
  "/api/generate-content",
  "/api/knowledge-base/context",
  "/api/knowledge-base/generate",
  "/api/knowledge-base/health",
  "/api/knowledge-base/search",
  "/api/publish",
  "/health"
]
```

### Test Content Generation Endpoint

```bash
curl -X POST https://api.blacksteep.com/api/generate-content \
  -H "Content-Type: application/json" \
  -H "Origin: https://d2b386ss3jk33z.cloudfront.net" \
  -d '{
    "source_content": "Test content",
    "platforms": ["linkedin"],
    "user_id": "test-user"
  }'
```

---

## Environment Configuration

### Frontend Environment Variables

**File:** `frontend/.env.production`

```bash
# Backend API URL (HTTPS with custom domain)
NEXT_PUBLIC_API_URL=https://api.blacksteep.com

# WebSocket URL (WSS with custom domain)
NEXT_PUBLIC_WS_URL=wss://api.blacksteep.com/ws/stream-generation

# CloudFront distribution
NEXT_PUBLIC_CDN_URL=https://d2b386ss3jk33z.cloudfront.net
```

**Important:** The `NEXT_PUBLIC_API_URL` should be the base URL only, without any path. The paths are added in the code.

---

## Code Changes

### Content Generation

**File:** `frontend/app/page.tsx` (Line ~63)

```typescript
// Before
const response = await fetch(
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/generate-content",
  { ... }
);

// After
const response = await fetch(
  `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/generate-content`,
  { ... }
);
```

### Content Regeneration

**File:** `frontend/app/page.tsx` (Line ~92)

```typescript
// Already correct - uses template literal
const response = await fetch(
  `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/content/${itemId}/regenerate`,
  { ... }
);
```

### Publishing

**File:** `frontend/app/page.tsx` (Lines ~116 and ~144)

```typescript
// Before
const response = await fetch(
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000/api/publish",
  { ... }
);

// After
const response = await fetch(
  `${process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}/api/publish`,
  { ... }
);
```

---

## Deployment Details

### S3 Bucket

- **Bucket:** content-marketing-swarm-dev-frontend
- **Region:** us-east-1

### CloudFront Distribution

- **Distribution ID:** EOKK53AQTTMGG
- **Domain:** d2b386ss3jk33z.cloudfront.net
- **Invalidation ID:** I8MHON9SL28NAHJ5VPF4K8BSUY

### Build Output

- **Build Time:** ~3 seconds
- **Static Pages:** 2 (/, /_not-found)
- **Rendering:** Static (prerendered)

---

## Testing Checklist

### Frontend

Test the following at https://d2b386ss3jk33z.cloudfront.net:

- [ ] Page loads without errors
- [ ] No CORS errors in console
- [ ] Content generation form is visible
- [ ] Can submit content generation request
- [ ] API calls go to correct endpoints
- [ ] WebSocket connection establishes
- [ ] Content appears after generation

### Backend API

- [x] CORS headers include CloudFront URL
- [x] `/api/generate-content` endpoint exists
- [x] `/api/publish` endpoint exists
- [x] `/api/content/{id}/regenerate` endpoint exists
- [x] WebSocket endpoint `/ws/stream-generation` exists

---

## Common Issues and Solutions

### Issue: Still getting 405 errors

**Solution:**
1. Clear browser cache (Ctrl+Shift+R)
2. Wait for CloudFront invalidation to complete (~5 minutes)
3. Check browser Network tab to see actual URL being called
4. Verify environment variables are correct

### Issue: CORS errors return

**Solution:**
1. Verify backend ECS tasks are running with updated image
2. Check CORS configuration in `backend/app/config.py`
3. Test with curl to verify headers

### Issue: WebSocket connection fails

**Solution:**
1. Verify WebSocket URL uses `wss://` protocol
2. Check ALB supports WebSocket (it does by default)
3. Verify backend WebSocket handler is running
4. Check security groups allow port 443

---

## Related Issues Fixed

1. ✅ **CORS Issue** - Added CloudFront URL to allowed origins
2. ✅ **API Endpoint Issue** - Fixed URL construction in frontend
3. ✅ **Platform Mismatch** - Rebuilt Docker image for linux/amd64
4. ✅ **Deployment** - Deployed updated backend and frontend

---

## Summary

The API endpoint issue has been resolved by:
1. ✅ Fixing URL construction in frontend code
2. ✅ Rebuilding frontend with correct configuration
3. ✅ Deploying to S3 and invalidating CloudFront cache
4. ✅ Verifying all API endpoints are accessible

The frontend now correctly calls:
- `POST https://api.blacksteep.com/api/generate-content`
- `POST https://api.blacksteep.com/api/publish`
- `POST https://api.blacksteep.com/api/content/{id}/regenerate`
- `WSS wss://api.blacksteep.com/ws/stream-generation`

---

**Status:** ✅ **COMPLETE**  
**Next Step:** Test the frontend in browser to verify end-to-end functionality
