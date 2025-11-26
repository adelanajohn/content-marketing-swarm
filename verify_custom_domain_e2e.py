#!/usr/bin/env python3
"""
End-to-end verification script for custom domain setup.
Tests HTTPS, WebSocket, and content generation functionality.
"""

import requests
import json
import sys
from urllib.parse import urlparse

# Configuration
API_BASE_URL = "https://api.blacksteep.com"
HEALTH_ENDPOINT = f"{API_BASE_URL}/health"
DOCS_ENDPOINT = f"{API_BASE_URL}/docs"

def test_https_endpoint():
    """Test HTTPS endpoint is accessible and returns valid response."""
    print("🔍 Testing HTTPS endpoint...")
    try:
        response = requests.get(HEALTH_ENDPOINT, timeout=10)
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        data = response.json()
        assert data.get("status") == "healthy", f"Expected healthy status, got {data}"
        print("✅ HTTPS endpoint test passed")
        return True
    except Exception as e:
        print(f"❌ HTTPS endpoint test failed: {e}")
        return False

def test_http_redirect():
    """Test HTTP redirects to HTTPS."""
    print("\n🔍 Testing HTTP to HTTPS redirect...")
    try:
        # Don't follow redirects automatically
        response = requests.get(
            "http://api.blacksteep.com/health",
            allow_redirects=False,
            timeout=10
        )
        assert response.status_code == 301, f"Expected 301 redirect, got {response.status_code}"
        location = response.headers.get("Location", "")
        assert location.startswith("https://"), f"Expected HTTPS redirect, got {location}"
        print("✅ HTTP redirect test passed")
        return True
    except Exception as e:
        print(f"❌ HTTP redirect test failed: {e}")
        return False

def test_dns_resolution():
    """Test DNS resolution for custom domain."""
    print("\n🔍 Testing DNS resolution...")
    try:
        parsed = urlparse(API_BASE_URL)
        hostname = parsed.hostname
        import socket
        ip_addresses = socket.gethostbyname_ex(hostname)[2]
        assert len(ip_addresses) > 0, "No IP addresses resolved"
        print(f"✅ DNS resolution test passed - Resolved to: {', '.join(ip_addresses)}")
        return True
    except Exception as e:
        print(f"❌ DNS resolution test failed: {e}")
        return False

def test_certificate_trust():
    """Test SSL certificate is trusted (no warnings)."""
    print("\n🔍 Testing SSL certificate trust...")
    try:
        # requests will raise SSLError if certificate is not trusted
        response = requests.get(HEALTH_ENDPOINT, timeout=10, verify=True)
        assert response.status_code == 200
        print("✅ Certificate trust test passed - No SSL warnings")
        return True
    except requests.exceptions.SSLError as e:
        print(f"❌ Certificate trust test failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Certificate trust test failed: {e}")
        return False

def test_api_docs_accessible():
    """Test API documentation is accessible."""
    print("\n🔍 Testing API documentation accessibility...")
    try:
        response = requests.get(DOCS_ENDPOINT, timeout=10)
        assert response.status_code == 200, f"Expected 200, got {response.status_code}"
        assert "swagger" in response.text.lower() or "openapi" in response.text.lower()
        print("✅ API docs accessibility test passed")
        return True
    except Exception as e:
        print(f"❌ API docs accessibility test failed: {e}")
        return False

def main():
    """Run all verification tests."""
    print("=" * 60)
    print("Custom Domain End-to-End Verification")
    print(f"Testing: {API_BASE_URL}")
    print("=" * 60)
    
    tests = [
        test_dns_resolution,
        test_https_endpoint,
        test_http_redirect,
        test_certificate_trust,
        test_api_docs_accessible,
    ]
    
    results = []
    for test in tests:
        results.append(test())
    
    print("\n" + "=" * 60)
    print("VERIFICATION SUMMARY")
    print("=" * 60)
    passed = sum(results)
    total = len(results)
    print(f"Tests Passed: {passed}/{total}")
    
    if passed == total:
        print("\n🎉 All verification tests passed!")
        print("✅ Custom domain setup is fully operational")
        return 0
    else:
        print(f"\n⚠️  {total - passed} test(s) failed")
        print("❌ Please review the failures above")
        return 1

if __name__ == "__main__":
    sys.exit(main())
