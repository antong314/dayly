#!/usr/bin/env python3
"""
Test script for authentication endpoints
Run with: python test_auth.py
"""

import requests
import json

BASE_URL = "http://localhost:8000"

def test_phone_verification():
    """Test phone verification endpoint"""
    print("Testing phone verification...")
    
    # Test with valid phone number
    response = requests.post(
        f"{BASE_URL}/api/auth/request-verification",
        json={"phone_number": "+1234567890"}
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    # Test with invalid phone number
    print("\nTesting with invalid phone number...")
    response = requests.post(
        f"{BASE_URL}/api/auth/request-verification",
        json={"phone_number": "1234567890"}  # Missing + prefix
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")

def test_code_verification():
    """Test code verification endpoint"""
    print("\n\nTesting code verification...")
    
    # Test with mock data (will fail without real OTP)
    response = requests.post(
        f"{BASE_URL}/api/auth/verify",
        json={
            "phone_number": "+1234567890",
            "code": "123456",
            "first_name": "Test User"
        }
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")
    
    # Test with invalid code format
    print("\nTesting with invalid code format...")
    response = requests.post(
        f"{BASE_URL}/api/auth/verify",
        json={
            "phone_number": "+1234567890",
            "code": "12345",  # Should be 6 digits
            "first_name": "Test User"
        }
    )
    
    print(f"Status: {response.status_code}")
    print(f"Response: {json.dumps(response.json(), indent=2)}")

def test_endpoints_available():
    """Test that endpoints are available"""
    print("Testing endpoint availability...")
    
    endpoints = [
        "/api/health",
        "/api/auth/request-verification",
        "/api/auth/verify",
        "/api/auth/refresh"
    ]
    
    for endpoint in endpoints:
        response = requests.options(f"{BASE_URL}{endpoint}")
        print(f"{endpoint}: {response.status_code} - {'Available' if response.status_code in [200, 405] else 'Not Available'}")

if __name__ == "__main__":
    print("Dayly Authentication Test Script")
    print("=" * 50)
    
    # First check if server is running
    try:
        response = requests.get(f"{BASE_URL}/api/health")
        if response.status_code == 200:
            print("✓ Server is running")
        else:
            print("✗ Server returned unexpected status")
            exit(1)
    except requests.exceptions.ConnectionError:
        print("✗ Server is not running. Start it with: uvicorn app.main:app --reload")
        exit(1)
    
    print("\n")
    
    # Test endpoints availability
    test_endpoints_available()
    
    print("\n" + "=" * 50 + "\n")
    
    # Note: These tests will fail without a real Supabase configuration
    print("NOTE: The following tests require a configured Supabase instance")
    print("They will show the expected request/response format\n")
    
    try:
        test_phone_verification()
        test_code_verification()
    except Exception as e:
        print(f"\nError during testing: {e}")
        print("This is expected if Supabase is not configured")
    
    print("\n" + "=" * 50)
    print("Test script completed")
