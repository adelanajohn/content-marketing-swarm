# Agent Platform Fix - Deployed

**Date:** November 26, 2025 11:54 UTC  
**Status:** ✅ **DEPLOYED**

---

## Issue Identified

The Creator Agent was only generating content for ONE platform instead of all requested platforms.

### Root Cause
The `platforms` parameter was being extracted from the WebSocket request and logged, but it was **never passed to the agent** via invocation_state.

**Evidence:**
- WebSocket logged: `Requested platforms: ['linkedin', 'twitter', 'pitch_deck']` ✅
- But invocation_state didn't include platforms ❌
- Agent had no way to know which platforms were requested ❌

---

## Fix Implemented

### 1. Updated InvocationState Class
**File:** `backend/app/state.py`

Added `platforms` parameter to:
- `__init__()` method
- `to_dict()` method  
- `create_invocation_state()` factory function

```python
def __init__(
    self,
    user_id: str,
    database_session: Session,
    ...
    platforms: Optional[list] = None  # NEW
):
    ...
    self.platforms = platforms or ["linkedin", "twitter", "pitch_deck"]
    logger.info(f"Invocation state initialized for user: {user_id}, platforms: {self.platforms}")
```

### 2. Updated WebSocket to Pass Platforms
**File:** `backend/app/api/websocket.py`

```python
invocation_state = create_invocation_state(
    user_id=str(user_id),
    database_session=db,
    brand_profile_id=brand_profile_id,
    kb_client=kb_client,
    gateway_client=gateway_client,
    gateway_url=settings.gateway_url,
    platforms=platforms  # NEW
)
```

### 3. Updated Creator Agent Instructions
**File:** `backend/app/agents/creator_agent.py`

Enhanced instructions to explicitly tell the agent to check `invocation_state["platforms"]`:

```
**CRITICAL: PLATFORM COMPLETENESS REQUIREMENT**
You MUST generate content for ALL requested platforms. The requested platforms are available in your invocation_state under the key "platforms".

IMPORTANT: Check invocation_state["platforms"] to see which platforms were requested. This is a list like ["linkedin", "twitter", "pitch_deck"].

You MUST generate content for EVERY platform in that list.
```

---

## Deployment

### Build
```bash
docker buildx build --platform linux/amd64 --no-cache -t content-marketing-swarm-backend:latest .
```

### Push
```bash
docker push 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest
```

**New Digest:** `sha256:8fe52679b456bd562fa46e7bb397784d534c3544350293515a0252f120952c5d`

### Deploy
```bash
# Registered task definition revision 8
aws ecs update-service \
  --cluster content-marketing-swarm-dev-cluster \
  --service content-marketing-swarm-dev-backend-service \
  --task-definition content-marketing-swarm-dev-backend:8 \
  --force-new-deployment
```

**Deployment Time:** 11:53 UTC  
**Status:** ✅ 2/2 tasks running with new image

---

## Expected Behavior After Fix

### Before Fix
1. User requests: `["linkedin", "twitter", "pitch_deck"]`
2. WebSocket logs platforms ✅
3. Agent doesn't see platforms ❌
4. Agent generates content for only 1 platform ❌

### After Fix
1. User requests: `["linkedin", "twitter", "pitch_deck"]`
2. WebSocket logs platforms ✅
3. Platforms passed to invocation_state ✅
4. Agent sees `invocation_state["platforms"]` ✅
5. Agent generates content for ALL 3 platforms ✅

---

## Verification Steps

### Test Content Generation
Generate content with all three platforms and check logs for:

1. **Platform Extraction (Hotfix 1):**
   ```
   Requested platforms: ['linkedin', 'twitter', 'pitch_deck']
   ```

2. **Platform in Invocation State (NEW):**
   ```
   Invocation state initialized for user: xxx, platforms: ['linkedin', 'twitter', 'pitch_deck']
   ```

3. **Multi-Platform Parsing (Hotfix 3):**
   ```
   Found 3 platform sections in markdown
   Parsed content item #1: platform='linkedin'
   Parsed content item #2: platform='twitter'
   Parsed content item #3: platform='pitch_deck'
   ```

4. **Content Items Created:**
   ```
   Creating final content item #1: platform='linkedin'
   Creating final content item #2: platform='twitter'
   Creating final content item #3: platform='pitch_deck'
   ```

---

## Remaining Issue: Image Generation

**Status:** Not fixed in this deployment

**Error:** `The provided [inputDimensions] does not meet the required format or standards`

**Impact:** Images fail to generate but content generation continues

**Priority:** Medium (content works without images)

**Next Steps:**
- Investigate Amazon Nova Canvas dimension requirements
- Update image generation parameters
- Deploy separate fix for image generation

---

## Summary

### What Was Fixed
✅ Platforms parameter now passed to agent via invocation_state  
✅ Agent instructions updated to check invocation_state["platforms"]  
✅ Agent should now generate content for ALL requested platforms

### What Still Needs Work
❌ Image generation dimension validation errors

### Deployment Status
✅ Code deployed at 11:53 UTC  
✅ Tasks running with correct image digest  
✅ Ready for testing

---

**Next Action:** User to test content generation with all three platforms

