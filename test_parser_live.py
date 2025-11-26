#!/usr/bin/env python3
"""
Direct test of the ContentParser to verify platform detection works correctly.
"""

import sys
sys.path.insert(0, 'backend')

from app.parsers.content_parser import ContentParser

# Test content with all three platforms
test_content = """
### 🐦 Twitter

Here's a great tweet about our product launch!

**Content:** Excited to announce our new AI-powered productivity tool! 🚀 
Transform your workflow in minutes. #AI #Productivity #Innovation

**Hashtags:** #AI #Productivity #Innovation #Tech

---

### 💼 LinkedIn

**Professional Post:**

We're thrilled to announce the launch of our revolutionary AI productivity platform.

After 18 months of development, we've created a solution that adapts to your workflow.

Key benefits:
- 40% time savings
- Seamless integration
- Intuitive interface

**Hashtags:** #AI #Productivity #Business #Innovation

---

### 📊 Pitch Deck

**Slide 1: Problem**

Modern teams waste 8 hours per week on repetitive tasks.

**Slide 2: Solution**

Our AI platform automates workflows while maintaining human oversight.

**Slide 3: Market**

$50B productivity software market growing at 15% annually.
"""

def main():
    print("\n" + "="*60)
    print("🧪 ContentParser Platform Detection Test")
    print("="*60 + "\n")
    
    parser = ContentParser()
    
    print("📝 Parsing multi-platform content...")
    print()
    
    # Parse the content
    parse_result = parser.parse_agent_output(
        agent_response=test_content,
        platform="linkedin",  # Default platform, will be overridden by section headers
        requested_platforms=["twitter", "linkedin", "pitch_deck"]
    )
    
    content_items = parse_result['content_items']
    print(f"✅ Parsed {len(content_items)} content items")
    print(f"   Completeness score: {parse_result['completeness_score']:.2%}")
    if parse_result['missing_platforms']:
        print(f"   ⚠️  Missing platforms: {parse_result['missing_platforms']}")
    print()
    
    # Group by platform
    by_platform = {}
    for item in content_items:
        platform = item.get('platform', 'unknown')
        if platform not in by_platform:
            by_platform[platform] = []
        by_platform[platform].append(item)
    
    print("📊 Content Distribution by Platform:")
    print()
    
    # Check each platform
    platforms_found = set(by_platform.keys())
    expected_platforms = {'twitter', 'linkedin', 'pitch_deck'}
    
    for platform in expected_platforms:
        if platform in platforms_found:
            count = len(by_platform[platform])
            print(f"  ✅ {platform}: {count} item(s)")
            
            # Show content preview
            for item in by_platform[platform]:
                preview = item.get('content', '')[:80].replace('\n', ' ')
                print(f"     Preview: {preview}...")
                hashtags = item.get('hashtags', [])[:3]
                print(f"     Hashtags: {', '.join(hashtags)}")
                print()
        else:
            print(f"  ❌ {platform}: NOT FOUND")
            print()
    
    # Check for unexpected platforms
    unexpected = platforms_found - expected_platforms
    if unexpected:
        print(f"  ⚠️  Unexpected platforms: {unexpected}")
        print()
    
    # Summary
    print("="*60)
    print("📊 Test Summary")
    print("="*60)
    print()
    
    success = expected_platforms == platforms_found
    
    if success:
        print("✅ SUCCESS: All platforms detected correctly!")
        print()
        print("Platform fixes are working:")
        print("  ✓ Twitter content detected and routed")
        print("  ✓ LinkedIn content detected and routed")
        print("  ✓ Pitch Deck content detected and routed")
        print()
    else:
        print("❌ FAILURE: Platform detection issues")
        print()
        print(f"Expected: {expected_platforms}")
        print(f"Found: {platforms_found}")
        print(f"Missing: {expected_platforms - platforms_found}")
        print()
    
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
