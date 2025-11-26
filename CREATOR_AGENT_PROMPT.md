# Creator Agent Prompt - Content Generation

## Current System Prompt

The Creator Agent uses the following system prompt for content generation:

### Agent Role
```
You are the Creator Agent in a content marketing swarm.
```

### Primary Responsibilities

#### 1. Content Generation
Transform source material into platform-specific content:
- **LinkedIn**: 150-300 words, professional tone, 3-5 hashtags
- **Twitter**: <280 characters per tweet, concise and engaging, 1-2 hashtags
- **Pitch Deck**: Bullet points and headlines optimized for slides

#### 2. Visual Asset Creation
Generate visual specifications and create images using Amazon Bedrock:
- Create detailed image descriptions with style guidelines
- Generate images using Amazon Nova Canvas
- Provide fallback text descriptions if image generation fails
- Ensure visuals match brand identity and platform requirements

#### 3. Brand Compliance
Validate all content against brand guidelines:
- Check for prohibited terms
- Verify tone and voice compliance
- Flag violations and suggest alternatives
- Ensure consistency with brand identity

#### 4. Content Quality Validation
After generating content for each platform:
1. Call `validate_content_quality` for each piece of generated content
2. Check if the quality score meets the minimum threshold (0.7)
3. If quality score is below 0.7, regenerate the content with improvements
4. Limit regeneration attempts to 2 per platform
5. Log quality metrics for monitoring

Quality validation checks:
- Grammar and spelling correctness
- Platform-specific constraints (character limits, word counts)
- Hashtag relevance and appropriateness
- Call-to-action presence
- Overall engagement potential

### Platform Completeness Requirement

The agent MUST generate content for ALL requested platforms:
- Check `invocation_state["platforms"]` for the list of requested platforms
- Generate content for EVERY platform in that list
- Verify all platforms are covered before completing response

Platform Checklist:
- ☐ LinkedIn (if "linkedin" in platforms list)
- ☐ Twitter (if "twitter" in platforms list)
- ☐ Pitch Deck (if "pitch_deck" in platforms list)

### Output Format Requirement

Use these EXACT header formats for proper parsing:
- For LinkedIn content: `### 💼 LinkedIn` OR `### LinkedIn`
- For Twitter content: `### 🐦 Twitter` OR `### Twitter`
- For Pitch Deck content: `### 📊 Pitch Deck` OR `### Pitch Deck`

### Example Output Format

```markdown
### 💼 LinkedIn

Excited to announce our latest innovation in AI-powered content marketing! 🚀

Our new platform helps businesses create engaging, platform-optimized content in minutes, not hours. With intelligent research integration and automated scheduling, you can focus on strategy while we handle execution.

Key benefits:
• Save 10+ hours per week on content creation
• Increase engagement by 3x with AI-optimized posts
• Maintain brand consistency across all platforms

Ready to transform your content marketing? Let's connect!

#ContentMarketing #AI #MarketingAutomation #DigitalMarketing #Innovation

**Media URLs:**
- https://s3.amazonaws.com/bucket/linkedin-ai-platform.png

---

### 🐦 Twitter

🚀 Launching our AI content marketing platform! Create engaging posts for LinkedIn, Twitter & pitch decks in minutes. Save 10+ hours/week & boost engagement 3x. #AI #ContentMarketing

**Media URLs:**
- https://s3.amazonaws.com/bucket/twitter-launch.png

---

### 📊 Pitch Deck

**Slide 1: Problem**
• Content creation takes 10+ hours per week
• Maintaining consistency across platforms is challenging
• Businesses struggle to optimize for each platform's unique requirements

**Slide 2: Solution**
• AI-powered content generation for multiple platforms
• Intelligent research integration for trending topics
• Automated scheduling and optimization

**Slide 3: Market Opportunity**
• $50B content marketing industry
• 70% of businesses struggle with content creation
• Growing demand for AI-powered solutions

**Media URLs:**
- https://s3.amazonaws.com/bucket/pitch-deck-problem.png
- https://s3.amazonaws.com/bucket/pitch-deck-solution.png
- https://s3.amazonaws.com/bucket/pitch-deck-market.png
```

---

## How to Improve Content Quality

### Issue: Poor Quality Content

If the generated content quality is poor, here are ways to improve it:

### 1. Enhance the User Prompt

**Current approach**: Simple prompts like "Generate content about AI"

**Better approach**: Provide detailed context and requirements

**Example of a good prompt**:
```
Generate content about our new AI-powered content marketing platform.

Product Details:
- Name: ContentSwarm AI
- Key Features: Multi-platform content generation, AI research integration, automated scheduling
- Target Audience: Marketing teams at B2B SaaS companies
- Unique Value: Save 10+ hours per week, increase engagement by 3x
- Pricing: Starting at $99/month

Tone: Professional but approachable, emphasize ROI and time savings
Call-to-Action: Sign up for free trial

Please generate content for LinkedIn, Twitter, and Pitch Deck.
```

### 2. Add Brand Guidelines

The system supports brand guidelines that can be configured per user:

**Brand Profile Structure**:
```python
{
    "name": "ContentSwarm AI",
    "tone": "professional, innovative, results-driven",
    "voice": "confident but approachable, data-driven",
    "prohibited_terms": ["cheap", "revolutionary", "game-changer"],
    "style_preferences": {
        "use_emojis": true,
        "use_statistics": true,
        "include_cta": true,
        "hashtag_style": "camelCase"
    }
}
```

### 3. Provide Source Material

Instead of generating from scratch, provide source material:

**Example**:
```
Generate content based on this blog post:

[Paste blog post content here]

Extract key points and transform them into platform-specific content for LinkedIn, Twitter, and Pitch Deck.
```

### 4. Use Research Agent Insights

The Research Agent provides:
- Trending topics in your industry
- Competitive positioning suggestions
- Recommended hashtags
- Audience preferences

These insights are automatically passed to the Creator Agent to improve relevance.

### 5. Iterate with Feedback

Use the regeneration endpoint to improve content:

```bash
POST /api/content/{item_id}/regenerate
{
  "feedback": "Make it more data-driven, add specific metrics, use a more professional tone"
}
```

### 6. Configure Quality Thresholds

The quality validation tool checks:
- **Grammar score** (0-1): Spelling and grammar correctness
- **Platform compliance** (0-1): Meets character limits and format requirements
- **Hashtag relevance** (0-1): Hashtags are relevant to content
- **Engagement score** (0-1): Has call-to-action, uses engaging language
- **Overall score** (0-1): Weighted average of all scores

Current threshold: **0.7** (70%)

To make quality requirements stricter, update the threshold in the Creator Agent configuration.

---

## Prompt Engineering Tips

### For LinkedIn Content

**Good prompt elements**:
- Specify the professional context
- Mention target audience (e.g., "marketing professionals", "CTOs")
- Request specific structure (e.g., "start with a hook, include 3 bullet points")
- Ask for data/statistics
- Specify hashtag count (3-5 recommended)

**Example**:
```
Generate LinkedIn content about our AI platform for marketing directors at B2B companies.

Structure:
1. Opening hook about time spent on content creation
2. Introduce our solution
3. 3 key benefits with metrics
4. Call-to-action for demo

Include 4-5 relevant hashtags. Use professional but engaging tone.
```

### For Twitter Content

**Good prompt elements**:
- Emphasize brevity and impact
- Request specific character count (aim for 240-260 to allow for retweets)
- Ask for emojis if appropriate
- Specify 1-2 hashtags maximum
- Request a clear call-to-action

**Example**:
```
Generate a Twitter post (max 260 characters) about our AI content platform.

Focus on the main benefit: saving 10+ hours per week.
Include 1 emoji and 2 hashtags.
End with a call-to-action link.
```

### For Pitch Deck Content

**Good prompt elements**:
- Specify slide structure (Problem, Solution, Market, Traction, Team)
- Request bullet points (3-5 per slide)
- Ask for metrics and data points
- Emphasize investor perspective
- Request visual descriptions for each slide

**Example**:
```
Generate pitch deck content for our AI content marketing platform.

Slides needed:
1. Problem: Time and consistency challenges in content marketing
2. Solution: Our AI-powered platform
3. Market: TAM/SAM/SOM with data
4. Traction: User growth, revenue, key metrics
5. Team: Founders' backgrounds

Use bullet points (3-5 per slide). Include specific metrics where possible.
Emphasize scalability and market opportunity.
```

---

## Quality Validation Tool

The `validate_content_quality` tool evaluates content on multiple dimensions:

### Scoring Criteria

```python
{
    "grammar_score": 0.0-1.0,        # Spelling and grammar
    "platform_compliance_score": 0.0-1.0,  # Format requirements
    "hashtag_relevance_score": 0.0-1.0,    # Hashtag quality
    "engagement_score": 0.0-1.0,     # Call-to-action, hooks
    "overall_score": 0.0-1.0,        # Weighted average
    "issues": [],                     # List of problems found
    "suggestions": []                 # Improvement recommendations
}
```

### Automatic Regeneration

If `overall_score < 0.7`:
1. Agent automatically regenerates content
2. Maximum 2 regeneration attempts
3. Best version is used if threshold not met
4. Content is flagged for manual review

---

## Improving the System Prompt

To improve content quality system-wide, you can enhance the Creator Agent prompt:

### Current Location
`backend/app/agents/creator_agent.py` - `instructions` variable

### Suggested Enhancements

1. **Add more specific examples** for each platform
2. **Include best practices** for engagement
3. **Add tone guidelines** (e.g., "avoid jargon", "use active voice")
4. **Specify content structure** more explicitly
5. **Add quality checklist** the agent should follow

### Example Enhancement

Add this section to the prompt:

```
**CONTENT QUALITY CHECKLIST**

Before finalizing content, verify:
✓ Opening hook grabs attention (first sentence)
✓ Clear value proposition stated
✓ Specific benefits with metrics when possible
✓ Active voice used throughout
✓ No jargon or buzzwords
✓ Clear call-to-action
✓ Appropriate hashtags (relevant, not overused)
✓ Proper grammar and spelling
✓ Platform-appropriate length
✓ Engaging and conversational tone
```

---

## Testing Content Quality

### Manual Testing

```bash
# Test with a detailed prompt
curl -X POST https://api.blacksteep.com/api/generate-content \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "550e8400-e29b-41d4-a716-446655440000",
    "prompt": "Generate content about our AI-powered content marketing platform. Key features: multi-platform generation, AI research, automated scheduling. Target audience: B2B marketing teams. Emphasize time savings (10+ hours/week) and engagement increase (3x). Professional but approachable tone.",
    "platforms": ["linkedin", "twitter", "pitch_deck"]
  }'
```

### Check Quality Scores

Look for quality metrics in the response or logs:
- Grammar score
- Platform compliance
- Hashtag relevance
- Engagement score
- Overall score

---

## Summary

**To improve content quality**:

1. ✅ **Provide detailed prompts** with context, target audience, and specific requirements
2. ✅ **Configure brand guidelines** for consistent tone and voice
3. ✅ **Supply source material** instead of generating from scratch
4. ✅ **Use the regeneration endpoint** with specific feedback
5. ✅ **Enhance the system prompt** with quality checklists and examples
6. ✅ **Adjust quality thresholds** to be more strict if needed

The system is designed to improve with better input. The more context and guidance you provide, the better the output quality will be.
