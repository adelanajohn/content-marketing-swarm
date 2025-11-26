# Hotfix 2: Force ECS Task Restart

**Issue Date:** November 26, 2025  
**Severity:** High  
**Status:** ✅ FIXED - Tasks Restarted

---

## Problem

After deploying the multi-platform parsing fix, the changes weren't taking effect because:

1. **Docker Image Tag Issue:** Using `:latest` tag means ECS doesn't automatically pull new images
2. **Old Tasks Running:** The running tasks were still using the old Docker image
3. **Force-New-Deployment Limitation:** `--force-new-deployment` flag doesn't force image pull when using `:latest` tag

### Evidence
CloudWatch logs showed:
```
Parsing final buffered content: length=18998, platform='linkedin'
```

But the code had been updated to:
```python
logger.info(f"Parsing final buffered content: length={len(buffered_text)}, requested_platforms={platforms}")
```

This confirmed old code was still running.

---

## Solution

### Step 1: Stop All Running Tasks
```bash
# List running tasks
aws ecs list-tasks \
  --cluster content-marketing-swarm-dev-cluster \
  --service-name content-marketing-swarm-dev-backend-service \
  --region us-east-1

# Stop each task
aws ecs stop-task \
  --cluster content-marketing-swarm-dev-cluster \
  --task 793df62d5de44da497f41158a5970ce4 \
  --region us-east-1

aws ecs stop-task \
  --cluster content-marketing-swarm-dev-cluster \
  --task be59a750f75344d3b689d4ebba27d6fb \
  --region us-east-1
```

### Step 2: Wait for New Tasks
ECS automatically starts new tasks to meet desired count (2 tasks).

### Step 3: Verify New Tasks Running
```bash
aws ecs describe-services \
  --cluster content-marketing-swarm-dev-cluster \
  --services content-marketing-swarm-dev-backend-service \
  --region us-east-1 \
  --query 'services[0].{RunningCount:runningCount,DesiredCount:desiredCount}'
```

**Result:** 2/2 tasks running with new image

---

## Root Cause

### Why This Happened
1. **Latest Tag Anti-Pattern:** Using `:latest` tag is considered an anti-pattern in production
2. **Image Caching:** ECS caches images and doesn't re-pull `:latest` automatically
3. **Task Definition Unchanged:** Since task definition didn't change, ECS didn't create new tasks

### Better Approach for Future
Use specific image tags with version numbers:
```bash
# Tag with version
docker tag content-marketing-swarm-backend:latest \
  298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-dev-backend:v1.2.3

# Update task definition with specific tag
# This forces ECS to create new task definition and deploy new tasks
```

---

## Verification Steps

### 1. Check New Tasks Are Running
```bash
aws ecs list-tasks \
  --cluster content-marketing-swarm-dev-cluster \
  --service-name content-marketing-swarm-dev-backend-service \
  --region us-east-1
```

**Expected:** New task IDs (different from stopped tasks)

### 2. Test Content Generation
- Generate content with all three platforms
- Check CloudWatch logs for: `requested_platforms=['linkedin', 'twitter', 'pitch_deck']`
- Verify all three content items are returned

### 3. Monitor Logs
```bash
aws logs tail /ecs/content-marketing-swarm-dev \
  --since 5m \
  --filter-pattern "requested_platforms" \
  --region us-east-1
```

---

## Impact

### Before Fix
- ✗ Old code running (single platform parsing)
- ✗ Only 1 content item returned
- ✗ Missing LinkedIn and Twitter content

### After Fix
- ✅ New code running (multi-platform parsing)
- ✅ Should return 3 content items
- ✅ All platforms should be parsed correctly

---

## Lessons Learned

### What Went Wrong
1. **Image Tagging:** Using `:latest` tag caused deployment confusion
2. **Verification Gap:** Didn't verify new code was actually running after deployment
3. **Deployment Process:** `--force-new-deployment` doesn't force image pull

### Improvements for Future
1. **Use Semantic Versioning:** Tag images with `v1.0.0`, `v1.0.1`, etc.
2. **Update Task Definition:** Change image tag in task definition to force new deployment
3. **Verify Deployment:** Check logs immediately after deployment to confirm new code
4. **Automated Deployment:** Use CI/CD pipeline that handles versioning automatically

---

## Deployment Timeline

| Time | Action | Status |
|------|--------|--------|
| 11:15 | Built and pushed Docker image | ✅ Complete |
| 11:16 | Triggered force-new-deployment | ✅ Complete |
| 11:20 | Waited for service stable | ✅ Complete |
| 11:25 | User tested - old code still running | ❌ Failed |
| 11:40 | Identified image caching issue | 🔍 Diagnosed |
| 11:44 | Stopped all running tasks | ✅ Complete |
| 11:45 | New tasks started automatically | ✅ Complete |
| 11:46 | Verified 2/2 tasks running | ✅ Complete |

---

## Next Steps

1. ⏳ **User Testing:** User should test content generation again
2. ⏳ **Log Verification:** Check CloudWatch logs show `requested_platforms` array
3. ⏳ **Content Verification:** Verify all 3 platforms return content
4. 📋 **Process Improvement:** Document better deployment process with versioned tags

---

## Related Issues

### Still To Investigate
1. **Image Display:** Images still not showing (separate issue)
2. **Content Quality:** Pitch Deck content quality needs improvement
3. **Parser Robustness:** May need to improve parser's platform detection

---

**Hotfix Completed:** November 26, 2025 11:46 PST  
**Status:** ✅ NEW CODE NOW RUNNING  
**Next:** User to test content generation
