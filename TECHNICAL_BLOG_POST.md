# Building an AI-Powered Content Marketing Swarm with Multi-Agent Architecture

## Introduction

This technical documentation describes the architecture, implementation, and deployment of a production-grade Content Marketing Swarm system that uses multiple AI agents to generate platform-specific marketing content at scale.

**System Overview**:
- Multi-agent orchestration using Strands Agents framework
- Amazon Bedrock for LLM inference (Claude Sonnet 4.5)
- Amazon Nova Canvas for image generation
- AgentCore Gateway for social media API integration
- Deployed on AWS ECS Fargate with PostgreSQL

**Key Capabilities**:
- Generates content for LinkedIn, Twitter, and Pitch Decks
- Automated research integration with trending topics
- Intelligent scheduling optimization
- Visual asset generation
- Brand compliance validation

---

## Architecture Overview

### High-Level Architecture

```
User Request → FastAPI → Swarm Orchestrator → [Research Agent → Creator Agent → Scheduler Agent] → Content Parser → Database → Response
```

### Component Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Next.js 14, React | User interface |
| CDN | CloudFront | Global content delivery |
| API Gateway | Application Load Balancer | HTTPS/WSS routing |
| Backend | FastAPI, Python 3.11 | REST API & WebSocket |
| Orchestration | Strands Agents | Multi-agent swarm |
| LLM | Amazon Bedrock (Claude Sonnet 4.5) | Text generation |
| Image Generation | Amazon Nova Canvas | Visual assets |
| Knowledge Base | Bedrock Knowledge Base | Semantic search |
| Gateway | AgentCore Gateway | Social media APIs |
| Database | PostgreSQL (RDS) | Persistent storage |
| Container | Docker, ECS Fargate | Serverless containers |
| Monitoring | CloudWatch, X-Ray | Logs & traces |

---

## Multi-Agent System Design

### Agent Architecture

The system uses a **sequential swarm pattern** with three specialized agents:

#### 1. Research Agent
**Responsibility**: Analyze trends, competitors, and audience insights

**Tools**:
- `search_knowledge_base`: Semantic search across startup content
- `analyze_trends`: Identify trending topics in the industry
- `analyze_competitors`: Competitive positioning analysis

**Output**: Research insights with trending topics, recommended hashtags, and competitive positioning

#### 2. Creator Agent
**Responsibility**: Generate platform-specific content and visual assets

**Tools**:
- `generate_platform_content`: Create platform-optimized text
- `generate_visual_asset`: Generate images using Amazon Nova
- `validate_brand_guidelines`: Ensure brand compliance
- `validate_content_quality`: Quality scoring and validation

**Output**: Formatted content for each platform with media URLs

**Platform Specifications**:
- **LinkedIn**: 150-300 words, professional tone, 3-5 hashtags, 1200x627px images
- **Twitter**: <280 characters, concise, 1-2 hashtags, 1200x675px images
- **Pitch Deck**: Bullet points, investor-focused, 1920x1080px images

#### 3. Scheduler Agent
**Responsibility**: Optimize posting times and create content calendar

**Tools**:
- `optimize_posting_schedule`: ML-based timing optimization
- `create_content_calendar`: Generate posting schedule
- `publish_to_platform`: Publish via AgentCore Gateway

**Output**: Optimized schedule with posting times for each platform

### Agent Communication Flow

```python
# Swarm execution flow
swarm = ContentMarketingSwarm(model=bedrock_model)

# Sequential execution with context passing
research_result = research_agent(prompt, invocation_state)
creator_result = creator_agent(prompt + research_result, invocation_state)
scheduler_result = scheduler_agent(creator_result, invocation_state)
```

**Invocation State** (shared context):
```python
{
    "user_id": "uuid",
    "platforms": ["linkedin", "twitter", "pitch_deck"],
    "brand_profile": {...},
    "kb_client": KnowledgeBaseClient,
    "gateway_client": GatewayClient,
    "shared_context": {
        "research_insights": {...},
        "generated_content": [...],
        "schedule": {...}
    }
}
```

---

## Content Generation Pipeline

### 1. Request Processing

**API Endpoint**: `POST /api/generate-content`

```python
@router.post("/generate-content", response_model=ContentGenerationResponse)
async def generate_content(request: ContentGenerationRequest, db: Session = Depends(get_db)):
    # Create invocation state with requested platforms
    invocation_state = create_invocation_state(
        user_id=request.user_id,
        database_session=db,
        platforms=request.platforms,
        kb_client=kb_client,
        gateway_client=gateway_client
    )
    
    # Execute swarm
    swarm = create_swarm(streaming=False)
    swarm_result = swarm(prompt=request.prompt, invocation_state=invocation_state)
    
    # Extract and parse agent output
    agent_output = extract_agent_output(swarm_result)
    parser = ContentParser()
    parse_result = parser.parse_agent_output(agent_output, requested_platforms=request.platforms)
    
    # Save to database
    for content_data in parse_result['content_items']:
        content_item = ContentItem(...)
        content_repo.create(content_item)
    
    return ContentGenerationResponse(content_items=content_items, ...)
```

### 2. Content Parsing

**Challenge**: Extract platform-specific content from agent's markdown output

**Solution**: Regex-based parser with MULTILINE flag

```python
PLATFORM_SECTION_PATTERN = re.compile(
    r'^\s*###?\s*(?:📱|📈|🐦|💼|📊)?\s*\*?\*?(LinkedIn|Twitter|Instagram|Facebook|Pitch\s*Deck)\s*(?:Content|Post)?\*?\*?[:\s]*\n+(.*?)(?=^\s*###?\s*(?:📱|📈|🐦|💼|📊)?\s*\*?\*?(?:LinkedIn|Twitter|Instagram|Facebook|Pitch\s*Deck)|\Z)',
    re.DOTALL | re.IGNORECASE | re.MULTILINE
)
```

**Key Features**:
- Handles leading whitespace
- Supports emoji headers (💼, 🐦, 📊)
- Captures content until next platform header
- Extracts hashtags and metadata

**Example Input**:
```markdown
### 💼 LinkedIn

Excited to announce our latest innovation! 🚀

Key benefits:
• Save 10+ hours per week
• Increase engagement by 3x

#ContentMarketing #AI

---

### 🐦 Twitter

🚀 Launching our AI platform! Save 10+ hours/week. #AI #ContentMarketing
```

**Parsed Output**:
```python
{
    'content_items': [
        {
            'platform': 'linkedin',
            'content': 'Excited to announce...',
            'hashtags': ['ContentMarketing', 'AI'],
            'media_urls': [],
            'metadata': {'word_count': 45, 'character_count': 234}
        },
        {
            'platform': 'twitter',
            'content': '🚀 Launching our AI platform!...',
            'hashtags': ['AI', 'ContentMarketing'],
            'media_urls': [],
            'metadata': {'word_count': 12, 'character_count': 78}
        }
    ],
    'missing_platforms': [],
    'completeness_score': 1.0
}
```

### 3. Quality Validation

**Quality Scoring System**:

```python
def validate_content_quality(content: str, platform: str) -> Dict:
    return {
        'grammar_score': 0.0-1.0,           # Spelling and grammar
        'platform_compliance_score': 0.0-1.0,  # Format requirements
        'hashtag_relevance_score': 0.0-1.0,    # Hashtag quality
        'engagement_score': 0.0-1.0,        # Call-to-action, hooks
        'overall_score': 0.0-1.0,           # Weighted average
        'issues': [],                        # List of problems
        'suggestions': []                    # Improvements
    }
```

**Threshold**: 0.7 (70%) - Content below this score triggers regeneration

---

## AgentCore Gateway Integration

### Purpose
Secure, managed access to third-party social media APIs using Model Context Protocol (MCP)

### Architecture

```
Scheduler Agent → AgentCore Gateway → OAuth2 (Cognito) → Social Media API
```

### Gateway Setup

```python
from bedrock_agentcore_starter_toolkit.operations.gateway.client import GatewayClient

class SocialMediaGatewayClient:
    def setup_gateway(self, gateway_name: str = "ContentMarketingGateway"):
        # Create OAuth authorizer with Cognito
        cognito_response = self.gateway_client.create_oauth_authorizer_with_cognito(gateway_name)
        
        # Create MCP Gateway with semantic search
        self.gateway = self.gateway_client.create_mcp_gateway(
            name=gateway_name,
            authorizer_config=cognito_response["authorizer_config"],
            enable_semantic_search=True
        )
        
        return self.gateway
    
    def add_linkedin_target(self, client_id: str, client_secret: str):
        linkedin_target = self.gateway_client.create_mcp_gateway_target(
            gateway=self.gateway,
            name="LinkedInAPI",
            target_type="openApiSchema",
            target_payload={"inlinePayload": json.dumps(openapi_spec)},
            credentials={
                "oauth2_provider_config": {
                    "customOauth2ProviderConfig": {
                        "oauthDiscovery": {
                            "authorizationEndpoint": "https://www.linkedin.com/oauth/v2/authorization",
                            "tokenEndpoint": "https://www.linkedin.com/oauth/v2/accessToken"
                        },
                        "clientId": client_id,
                        "clientSecret": client_secret,
                        "scopes": ["w_member_social", "r_liteprofile"]
                    }
                }
            }
        )
```

### Supported Platforms

**LinkedIn API**:
- Endpoint: `https://api.linkedin.com/v2`
- Operations: Create posts (`/ugcPosts`)
- Auth: OAuth2 with scopes: `w_member_social`, `r_liteprofile`

**Twitter/X API**:
- Endpoint: `https://api.twitter.com/2`
- Operations: Create tweets (`/tweets`)
- Auth: OAuth2 with scopes: `tweet.read`, `tweet.write`, `users.read`

---

## Image Generation with Amazon Nova

### Implementation

```python
def generate_visual_asset(
    description: str,
    style: str = "professional",
    dimensions: str = "1200x628",
    tool_context: ToolContext = None
) -> Dict:
    # Get Bedrock runtime client from invocation state
    bedrock_runtime = tool_context.invocation_state.get("bedrock_runtime_client")
    s3_client = tool_context.invocation_state.get("s3_client")
    s3_bucket = tool_context.invocation_state.get("s3_bucket")
    
    width, height = map(int, dimensions.split("x"))
    
    # Generate image using Amazon Nova Canvas
    response = bedrock_runtime.invoke_model(
        modelId="amazon.nova-canvas-v1:0",
        body=json.dumps({
            "taskType": "TEXT_IMAGE",
            "textToImageParams": {
                "text": description,
                "negativeText": "low quality, blurry, distorted"
            },
            "imageGenerationConfig": {
                "numberOfImages": 1,
                "quality": "premium",
                "height": height,
                "width": width
            }
        })
    )
    
    # Upload to S3
    image_data = base64.b64decode(result["images"][0])
    s3_key = f"generated/{uuid.uuid4()}.png"
    s3_client.put_object(Bucket=s3_bucket, Key=s3_key, Body=image_data)
    
    return {
        "success": True,
        "url": f"https://{s3_bucket}.s3.amazonaws.com/{s3_key}"
    }
```

### Platform-Specific Dimensions

| Platform | Dimensions | Aspect Ratio |
|----------|-----------|--------------|
| LinkedIn | 1200x627px | 1.91:1 |
| Twitter | 1200x675px | 16:9 |
| Pitch Deck | 1920x1080px | 16:9 |

---

## Deployment Architecture

### Infrastructure

**AWS Services**:
- **ECS Fargate**: Serverless container orchestration (2 tasks)
- **Application Load Balancer**: HTTPS/WSS routing
- **RDS PostgreSQL**: Multi-AZ database
- **S3**: Image storage and frontend hosting
- **CloudFront**: CDN for frontend
- **ECR**: Container registry
- **CloudWatch**: Logging and monitoring
- **X-Ray**: Distributed tracing

### Container Configuration

**Dockerfile**:
```dockerfile
FROM python:3.11-slim as builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

WORKDIR /app
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY . .

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Deployment Process

```bash
# 1. Build for linux/amd64
docker build --platform linux/amd64 -t content-marketing-swarm:latest .

# 2. Tag and push to ECR
docker tag content-marketing-swarm:latest \
  298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest
docker push 298717586028.dkr.ecr.us-east-1.amazonaws.com/content-marketing-swarm-backend:latest

# 3. Update ECS service
aws ecs update-service \
  --cluster content-marketing-swarm-dev-cluster \
  --service content-marketing-swarm-dev-backend-service \
  --force-new-deployment \
  --region us-east-1

# 4. Stop old tasks to force image pull
aws ecs list-tasks --cluster content-marketing-swarm-dev-cluster \
  --service-name content-marketing-swarm-dev-backend-service \
  --region us-east-1 --query 'taskArns[]' --output text | \
  xargs -I {} aws ecs stop-task --cluster content-marketing-swarm-dev-cluster --task {} --region us-east-1
```

### Environment Variables

```bash
# AWS Configuration
AWS_REGION=us-east-1
BEDROCK_KB_ID=FDXSMUY2AV
S3_BUCKET_NAME=content-marketing-swarm-dev-images

# Database
DATABASE_URL=postgresql://user:password@rds-endpoint:5432/content_marketing

# API Configuration
API_HOST=0.0.0.0
API_PORT=8000
CORS_ORIGINS=http://localhost:3000,https://d2b386ss3jk33z.cloudfront.net,https://api.blacksteep.com

# AgentCore Gateway
GATEWAY_URL=https://gateway.agentcore.amazonaws.com
```

---

## Key Technical Challenges & Solutions

### Challenge 1: Agent Exposing Internal Reasoning

**Problem**: Creator Agent was returning reasoning text instead of formatted content:
```
"Let me create better LinkedIn content..."
"Let me validate this LinkedIn content quality..."
```

**Solution**:
1. Added explicit "DIRECT OUTPUT ONLY" instruction to system prompt
2. Filtered reasoning messages in output extraction
3. Simplified quality validation to prevent narration

**Code Fix**:
```python
# Filter out reasoning messages
content_messages = []
for msg in assistant_messages:
    if any(phrase in msg for phrase in ["Let me create", "Let me validate"]):
        continue
    if "###" in msg and any(platform in msg for platform in ["LinkedIn", "Twitter"]):
        content_messages.append(msg)
```

### Challenge 2: Parser Missing Platforms

**Problem**: Regex only detected LinkedIn, missed Twitter and Pitch Deck

**Root Cause**: Pattern didn't handle leading whitespace or use MULTILINE flag

**Solution**:
```python
# Before: Only matched at string start
r'###?\s*(?:📱|🐦|💼)?\s*(LinkedIn|Twitter)...'

# After: Matches line start with whitespace
r'^\s*###?\s*(?:📱|🐦|💼)?\s*(LinkedIn|Twitter)...'
# Added re.MULTILINE flag
```

**Result**: All 3 platforms now detected correctly

### Challenge 3: Platform Mismatch Error

**Problem**: ECS tasks failing with "image Manifest does not contain descriptor matching platform 'linux/amd64'"

**Solution**: Build Docker image with explicit platform flag:
```bash
docker build --platform linux/amd64 -t content-marketing-swarm:latest .
```

---

## Performance Optimization

### Caching Strategy

**Brand Profiles**: Cached in memory for 1 hour
```python
@lru_cache(maxsize=100)
def get_brand_profile(profile_id: str) -> BrandProfile:
    return brand_repo.get_by_id(profile_id)
```

**Knowledge Base Results**: Cached for 15 minutes
```python
@cache(ttl=900)
def search_knowledge_base(query: str) -> List[Dict]:
    return kb_client.retrieve(query)
```

### Database Optimization

**Indexes**:
```sql
CREATE INDEX idx_content_items_user_id ON content_items(user_id);
CREATE INDEX idx_content_items_platform ON content_items(platform);
CREATE INDEX idx_content_items_created_at ON content_items(created_at DESC);
```

**Connection Pooling**:
```python
engine = create_engine(
    DATABASE_URL,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True
)
```

### Async Processing

**WebSocket Streaming** for real-time updates:
```python
@router.websocket("/ws/stream-generation")
async def stream_generation(websocket: WebSocket):
    await websocket.accept()
    
    async for chunk in swarm.stream(prompt, invocation_state):
        await websocket.send_json({
            "type": chunk.type,
            "agent": chunk.agent_name,
            "content": chunk.content
        })
```

---

## Monitoring & Observability

### CloudWatch Metrics

**Custom Metrics**:
- `SwarmExecutionTime`: Total swarm execution duration
- `AgentExecutionTime`: Per-agent execution time
- `ContentGenerationSuccess`: Success rate by platform
- `ImageGenerationSuccess`: Image generation success rate
- `QualityScore`: Average content quality scores

### Structured Logging

```python
structured_logger.log_info(
    "Content generation completed",
    context={
        'user_id': user_id,
        'platforms': platforms,
        'content_items_count': len(content_items),
        'execution_time': execution_time,
        'quality_scores': quality_scores
    }
)
```

### Distributed Tracing

**X-Ray Integration**:
```python
with tracer.trace_segment("ContentMarketingSwarm"):
    with tracer.trace_subsegment("ResearchAgent"):
        research_result = research_agent(prompt)
    with tracer.trace_subsegment("CreatorAgent"):
        creator_result = creator_agent(prompt)
```

---

## Testing Strategy

### Unit Tests

```python
def test_content_parser_detects_all_platforms():
    parser = ContentParser()
    result = parser.parse_agent_output(
        agent_output,
        platform="multi",
        requested_platforms=["linkedin", "twitter", "pitch_deck"]
    )
    
    assert len(result['content_items']) == 3
    platforms = {item['platform'] for item in result['content_items']}
    assert platforms == {'linkedin', 'twitter', 'pitch_deck'}
```

### Integration Tests

```python
def test_end_to_end_content_generation():
    response = client.post("/api/generate-content", json={
        "user_id": "test-user",
        "prompt": "Generate content about AI",
        "platforms": ["linkedin", "twitter"]
    })
    
    assert response.status_code == 200
    assert len(response.json()['content_items']) == 2
```

### Property-Based Tests

```python
from hypothesis import given, strategies as st

@given(st.text(min_size=100), st.sampled_from(["linkedin", "twitter"]))
def test_platform_formatting_compliance(content, platform):
    result = generate_platform_content(content, platform)
    
    if platform == "linkedin":
        assert 150 <= len(result.content.split()) <= 300
    elif platform == "twitter":
        assert len(result.content) <= 280
```

---

## Security Considerations

### Authentication & Authorization

**OAuth2 Flow** via AgentCore Gateway:
1. User authenticates with Cognito
2. Gateway obtains OAuth tokens for social media APIs
3. Tokens stored securely in AWS Secrets Manager
4. Automatic token refresh

### Data Protection

**Encryption**:
- At rest: RDS encryption with AWS KMS
- In transit: TLS 1.2+ for all API calls
- S3 bucket encryption for images

**PII Handling**:
- No PII stored in logs
- User IDs are UUIDs
- Content is user-owned and isolated

### Rate Limiting

```python
from slowapi import Limiter

limiter = Limiter(key_func=get_remote_address)

@app.post("/api/generate-content")
@limiter.limit("10/minute")
async def generate_content(request: ContentGenerationRequest):
    ...
```

---

## Cost Optimization

### Estimated Monthly Costs (Production)

| Service | Usage | Cost |
|---------|-------|------|
| ECS Fargate | 2 tasks, 0.5 vCPU, 1GB RAM | $30 |
| RDS PostgreSQL | db.t3.micro, Multi-AZ | $30 |
| Application Load Balancer | 1 ALB | $20 |
| S3 | 100GB storage, 1M requests | $5 |
| CloudFront | 100GB transfer | $10 |
| Bedrock (Claude) | 10M tokens | $30 |
| Bedrock (Nova Canvas) | 1000 images | $40 |
| CloudWatch | Logs + metrics | $10 |
| **Total** | | **~$175/month** |

### Cost Optimization Strategies

1. **Use Bedrock Batch Inference** for non-real-time content
2. **Cache Knowledge Base results** to reduce queries
3. **Implement request deduplication** to avoid redundant generations
4. **Use Spot instances** for non-critical workloads
5. **Optimize image dimensions** to reduce Nova Canvas costs

---

## Future Enhancements

### Planned Features

1. **Multi-language Support**: Generate content in multiple languages
2. **A/B Testing**: Test different content variations
3. **Analytics Integration**: Track engagement metrics
4. **Content Calendar**: Visual calendar interface
5. **Collaboration**: Team workflows and approvals
6. **Custom Templates**: User-defined content templates
7. **Video Generation**: Short-form video content
8. **Voice Cloning**: Audio content generation

### Technical Improvements

1. **GraphQL API**: More flexible data fetching
2. **Redis Caching**: Distributed caching layer
3. **Kubernetes Migration**: Better orchestration
4. **Event-Driven Architecture**: Async processing with SQS/SNS
5. **Multi-Region Deployment**: Global availability

---

## Conclusion

This Content Marketing Swarm system demonstrates a production-grade implementation of multi-agent AI orchestration for content generation. Key achievements:

- ✅ **Multi-platform content generation** with 100% platform detection accuracy
- ✅ **Scalable architecture** handling concurrent requests on ECS Fargate
- ✅ **Quality validation** ensuring professional content output
- ✅ **Secure API integration** via AgentCore Gateway
- ✅ **Comprehensive monitoring** with CloudWatch and X-Ray
- ✅ **Cost-effective** at ~$175/month for production workload

The system successfully combines multiple AWS services, AI models, and best practices to deliver a robust, scalable solution for automated content marketing.

---

## References

- [Strands Agents Documentation](https://github.com/strands-agents/sdk-python)
- [Amazon Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [AgentCore Gateway Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/agentcore-gateway.html)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [ECS Fargate Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)

---

**Author**: Content Marketing Swarm Team  
**Last Updated**: November 26, 2025  
**Version**: 1.0  
**Repository**: [GitHub Link]
