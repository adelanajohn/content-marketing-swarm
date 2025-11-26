# Root Cause: Multiple Repository Confusion + ECS Image Caching

**Date:** November 26, 2025 11:25 UTC  
**Status:** 🔴 **CRITICAL ISSUE IDENTIFIED**

---

## The Real Problem

### Issue 1: Wrong ECR Repository
**Discovery:** There are TWO ECR repositories:
1. `content-marketing-swarm-backend` ← Task definition uses THIS
2. `content-marketing-swarm-dev-backend` ← I was pushing to THIS

**Evidence:**
```bash
# Task definition points to:
298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest

# I was pushing to:
298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-dev-backend:latest
```

**Result:** Tasks were pulling from the WRONG repository with old code!

### Issue 2: ECS Node Image Caching
Even after pushing to the correct repository, ECS nodes cache Docker images.

**Evidence:**
```bash
# ECR has correct image:
Digest: sha256:80bf6ba3d275aa8b5b025601bca467710fb88c4c069233512a17987499ef827f

# But task is running:
ImageDigest: sha256:fa528cafd5345177ee6795752c540e14bf6283eb9ab9d2ace33a6a064a2de0cb
```

**Result:** Tasks pull cached image from node, not fresh image from ECR!

---

## Why `:latest` Tag Is Dangerous

### The Problem
When using `:latest` tag:
1. ECS checks if image exists locally on node
2. If yes, uses cached image (even if ECR has newer version)
3. Only pulls from ECR if image doesn't exist locally

### The Solution
Use **image digest** or **version tags** instead of `:latest`:

```bash
# BAD (uses cache):
image: 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest

# GOOD (forces pull):
image: 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend@sha256:80bf6ba...
```

---

## Deployment Attempts Timeline

### Attempt 1 (11:06 UTC) - FAILED ❌
- **Problem:** Docker used cached layers
- **Fix:** Rebuilt with `--no-cache`

### Attempt 2 (11:15 UTC) - FAILED ❌
- **Problem:** Pushed to wrong ECR repository (`-dev-backend`)
- **Fix:** Pushed to correct repository (`backend`)

### Attempt 3 (11:22 UTC) - FAILED ❌
- **Problem:** ECS nodes cached old image
- **Status:** Still failing

---

## Next Steps

### Option 1: Force Image Pull with Digest (RECOMMENDED)
Update task definition to use specific image digest:

```bash
# Get current task definition
aws ecs describe-task-definition \
  --task-definition content-marketing-swarm-dev-backend \
  --query 'taskDefinition' > task-def.json

# Edit task-def.json to use digest instead of :latest
# Change:
#   "image": "298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest"
# To:
#   "image": "298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend@sha256:80bf6ba3d275aa8b5b025601bca467710fb88c4c069233512a17987499ef827f"

# Register new task definition
aws ecs register-task-definition --cli-input-json file://task-def.json

# Update service to use new task definition
aws ecs update-service \
  --cluster content-marketing-swarm-dev-cluster \
  --service content-marketing-swarm-dev-backend-service \
  --task-definition content-marketing-swarm-dev-backend:NEW_REVISION \
  --force-new-deployment
```

### Option 2: Drain ECS Nodes
Force ECS to start tasks on different nodes:

```bash
# This is more complex and requires draining nodes
# Not recommended for quick fix
```

### Option 3: Use Version Tags
Instead of `:latest`, use semantic versioning:

```bash
# Tag with version
docker tag content-marketing-swarm-backend:latest \
  298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:v1.0.1

# Push versioned tag
docker push 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:v1.0.1

# Update task definition to use v1.0.1
```

---

## Lessons Learned

### Critical Mistakes

1. **Repository Name Confusion**
   - Two similar repository names caused confusion
   - Should have verified task definition first
   - **Fix:** Always check task definition before pushing

2. **`:latest` Tag Anti-Pattern**
   - `:latest` tag causes caching issues
   - ECS doesn't force-pull `:latest` images
   - **Fix:** Use digests or version tags

3. **Docker Layer Caching**
   - Docker cached old code in layers
   - **Fix:** Always use `--no-cache` for critical deployments

4. **Insufficient Verification**
   - Didn't verify image digest after deployment
   - **Fix:** Check running task's image digest matches ECR

---

## Why This Is So Hard

### Multiple Caching Layers
1. **Docker Build Cache:** Caches layers during build
2. **ECR:** Stores images
3. **ECS Node Cache:** Caches pulled images locally
4. **`:latest` Tag:** Doesn't force cache invalidation

### The Perfect Storm
All four caching layers conspired to prevent deployment:
1. Docker cached old code → Fixed with `--no-cache`
2. Pushed to wrong ECR repo → Fixed by pushing to correct repo
3. ECS node cached old image → Still not fixed!
4. `:latest` tag doesn't force pull → Need to fix with digest

---

## Recommended Fix

I'll update the task definition to use the image digest, which will force ECS to pull the exact image from ECR, bypassing all caches.

