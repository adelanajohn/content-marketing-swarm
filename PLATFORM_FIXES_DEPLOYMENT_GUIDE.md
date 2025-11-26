# Platform Panel Fixes - Deployment Guide

## 🐛 Issue Identified

After testing the live deployment at `api.blacksteep.com`, we discovered that:

1. **No Twitter content is being generated** - Twitter panel is empty
2. **No Pitch Deck content is being generated** - Pitch Deck panel is empty  
3. **No images are being displayed** - Media URLs not included in output

## 🔍 Root Cause Analysis

The issue is in the **Creator Agent instructions**. The agent was not told to:

1. Format its output with markdown section headers (`### Twitter`, `### Pitch Deck`, etc.)
2. Include image URLs in a structured format that the parser can extract

Without these headers, the ContentParser cannot detect which platform each piece of content belongs to, so everything defaults to the requested platform (usually LinkedIn).

### How the System Works

```
Agent generates content
    ↓
Agent formats with markdown headers (### Twitter, ### Pitch Deck)
    ↓
ContentParser.parse_agent_output() looks for these headers
    ↓
Parser extracts platform from header and normalizes it
    ↓
Content routed to correct panel in UI
```

**The Missing Link:** The agent wasn't formatting output with the required headers!

## ✅ Fix Applied

Updated `backend/app/agents/creator_agent.py` to include explicit formatting instructions:

### Changes Made

1. **Added Output Format Requirements** to agent instructions:
   ```
   **CRITICAL OUTPUT FORMAT REQUIREMENT:**
   You MUST format your final response with markdown section headers for each platform.
   
   Use these EXACT header formats:
   - For LinkedIn content: ### 💼 LinkedIn  OR  ### LinkedIn
   - For Twitter content: ### 🐦 Twitter  OR  ### Twitter
   - For Pitch Deck content: ### 📊 Pitch Deck  OR  ### Pitch Deck
   ```

2. **Added Example Output Structure** showing the agent exactly how to format:
   ```markdown
   ### 💼 LinkedIn
   
   [Content here]
   
   **Media URLs:**
   - https://s3.amazonaws.com/bucket/image1.png
   
   ---
   
   ### 🐦 Twitter
   
   [Content here]
   
   **Media URLs:**
   - https://s3.amazonaws.com/bucket/twitter-image.png
   ```

3. **Added Image URL Instructions**:
   ```
   IMPORTANT: When you generate images using the generate_visual_asset tool, 
   include the returned image URLs in your output under a "**Media URLs:**" 
   section for each platform.
   ```

## 🚀 Deployment Steps

### Option 1: Quick Deployment (Recommended)

```bash
cd backend
./scripts/deploy_agent_fix.sh
```

This script will:
1. Build a new Docker image with the updated agent instructions
2. Push to ECR
3. Force ECS to redeploy with the new image
4. Takes ~2-3 minutes

### Option 2: Manual Deployment

```bash
cd backend

# Build image
docker build -t content-marketing-swarm-backend:latest .

# Tag for ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REPO="${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend"
docker tag content-marketing-swarm-backend:latest ${ECR_REPO}:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
    docker login --username AWS --password-stdin ${ECR_REPO}

# Push
docker push ${ECR_REPO}:latest

# Update ECS service
aws ecs update-service \
    --cluster content-marketing-swarm-dev-cluster \
    --service content-marketing-swarm-dev-backend-service \
    --force-new-deployment \
    --region us-east-1
```

## 🧪 Verification Steps

After deployment completes (2-3 minutes):

### 1. Check ECS Service Status

```bash
aws ecs describe-services \
    --cluster content-marketing-swarm-dev-cluster \
    --services content-marketing-swarm-dev-backend-service \
    --region us-east-1 \
    --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'
```

Expected: `Status: ACTIVE`, `Running: 2`, `Desired: 2`

### 2. Check Backend Health

```bash
curl https://api.blacksteep.com/health
```

Expected: `{"status":"healthy"}`

### 3. Generate Test Content

Visit `https://d2b386ss3jk33z.cloudfront.net` and:

1. Enter a prompt requesting content for all platforms:
   ```
   Create content for LinkedIn, Twitter, and Pitch Deck about our new AI productivity tool
   ```

2. Verify content appears in all three panels:
   - ✅ LinkedIn panel shows LinkedIn content
   - ✅ Twitter panel shows Twitter content  
   - ✅ Pitch Deck panel shows Pitch Deck content

3. Verify images display (if image generation is enabled)

### 4. Check Logs

```bash
aws logs tail /ecs/content-marketing-swarm-dev --follow --region us-east-1
```

Look for:
- `Detected platform section: Twitter → twitter`
- `Detected platform section: Pitch Deck → pitch_deck`
- `Parsed content item #1: platform='twitter'`
- `Parsed content item #2: platform='pitch_deck'`

## 📊 Expected Results

After the fix is deployed:

### Before Fix
- ❌ Only LinkedIn content generated
- ❌ Twitter panel empty
- ❌ Pitch Deck panel empty
- ❌ No images displayed

### After Fix
- ✅ LinkedIn content in LinkedIn panel
- ✅ Twitter content in Twitter panel
- ✅ Pitch Deck content in Pitch Deck panel
- ✅ Images displayed in all panels (when generated)

## 🔧 Technical Details

### Parser Behavior

The `ContentParser.parse_agent_output()` method uses this regex to detect platforms:

```python
PLATFORM_SECTION_PATTERN = re.compile(
    r'###?\s*(?:📱|📈|🐦|💼|📊)?\s*\*?\*?(LinkedIn|Twitter|Instagram|Facebook|Pitch\s*Deck)\s*(?:Content|Post)?\*?\*?[:\s]*\n+(.*?)(?=\n###?\s*(?:📱|📈|🐦|💼|📊)|\Z)',
    re.DOTALL | re.IGNORECASE
)
```

This matches:
- `### Twitter` → platform="Twitter"
- `### 🐦 Twitter` → platform="Twitter"
- `### Pitch Deck` → platform="Pitch Deck"
- `### 📊 Pitch Deck` → platform="Pitch Deck"

Then `_normalize_platform_name()` converts:
- "Twitter" → "twitter"
- "Pitch Deck" → "pitch_deck"
- "LinkedIn" → "linkedin"

### Why This Fix Works

1. **Agent now knows the format** - Explicit instructions with examples
2. **Parser can detect platforms** - Markdown headers match the regex
3. **Content routes correctly** - Normalized platform names match panel filters
4. **Images included** - Agent told to add Media URLs section

## 🎯 Success Criteria

- [ ] Deployment completes without errors
- [ ] ECS tasks restart successfully
- [ ] Health check passes
- [ ] Twitter content appears in Twitter panel
- [ ] Pitch Deck content appears in Pitch Deck panel
- [ ] Images display when generated
- [ ] All existing tests still pass

## 📝 Rollback Plan

If issues occur after deployment:

```bash
# Rollback to previous task definition
aws ecs update-service \
    --cluster content-marketing-swarm-dev-cluster \
    --service content-marketing-swarm-dev-backend-service \
    --task-definition content-marketing-swarm-dev-backend:PREVIOUS_REVISION \
    --region us-east-1
```

Replace `PREVIOUS_REVISION` with the previous task definition revision number.

## 🔍 Troubleshooting

### Issue: Content still not appearing in correct panels

**Check:**
1. Verify new image is deployed: `docker images | grep content-marketing-swarm`
2. Check ECS task definition revision increased
3. View agent output in logs to see if headers are present
4. Test parser directly with `python test_parser_live.py`

### Issue: Images still not displaying

**Check:**
1. Verify S3 bucket permissions
2. Check if `generate_visual_asset` tool is being called
3. Verify Amazon Nova Canvas model access in Bedrock
4. Check CloudWatch logs for image generation errors

### Issue: Deployment fails

**Check:**
1. ECR repository exists and is accessible
2. ECS cluster and service exist
3. AWS credentials are valid
4. Docker daemon is running

## 📚 Related Documentation

- **Requirements:** `.kiro/specs/platform-panel-fixes/requirements.md`
- **Design:** `.kiro/specs/platform-panel-fixes/design.md`
- **Test Results:** `PLATFORM_FIXES_TEST_RESULTS.md`
- **Parser Code:** `backend/app/parsers/content_parser.py`
- **Agent Code:** `backend/app/agents/creator_agent.py`

---

**Last Updated:** November 25, 2025  
**Status:** Ready for Deployment  
**Priority:** High - Fixes critical UI functionality

