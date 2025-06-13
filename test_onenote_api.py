#!/usr/bin/env python3
"""
Quick OneNote Graph API Test Script
Test your Azure app registration and OneNote access
"""

import json
import requests
from msal import PublicClientApplication

# CONFIGURE THESE VALUES
CLIENT_ID = "8a52ee61-c61a-4873-bfc6-489fa574e92c"  # Replace with your actual client ID
TENANT_ID = "d8fe6df3-c89e-4fa6-a2f8-cfcc31dffb1c"  # Use "common" for personal accounts, or your tenant ID for corporate

def test_authentication():
    """Test authentication with Microsoft Graph"""
    print("🔐 Testing Authentication...")
    print(f"Client ID: {CLIENT_ID}")
    print(f"Tenant ID: {TENANT_ID}")
    print()
    
    if CLIENT_ID == "YOUR_CLIENT_ID_HERE":
        print("❌ Please edit this script and add your actual client ID!")
        return None
    
    # Create MSAL app
    app = PublicClientApplication(
        CLIENT_ID,
        authority=f"https://login.microsoftonline.com/{TENANT_ID}"
    )
    
    # Try to get token from cache first
    accounts = app.get_accounts()
    if accounts:
        print("📋 Found cached account, trying silent authentication...")
        result = app.acquire_token_silent(
            scopes=["User.Read", "Notes.Read.All"],
            account=accounts[0]
        )
    else:
        result = None
    
    # If no cached token, get new one interactively
    if not result:
        print("🌐 Opening browser for authentication...")
        result = app.acquire_token_interactive(
            scopes=["User.Read", "Notes.Read.All", "Notes.ReadWrite.All"]
        )
    
    if "access_token" in result:
        print("✅ Authentication successful!")
        return result["access_token"]
    else:
        print(f"❌ Authentication failed: {result.get('error_description', 'Unknown error')}")
        return None

def test_graph_api(access_token):
    """Test Microsoft Graph API access"""
    print("\n📊 Testing Microsoft Graph API...")
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    # Test basic Graph API access
    try:
        response = requests.get(
            'https://graph.microsoft.com/v1.0/me',
            headers=headers
        )
        
        if response.status_code == 200:
            user_info = response.json()
            print(f"✅ Graph API access works!")
            print(f"   User: {user_info.get('displayName', 'Unknown')}")
            print(f"   Email: {user_info.get('mail', user_info.get('userPrincipalName', 'Unknown'))}")
            return True
        else:
            print(f"❌ Graph API access failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error accessing Graph API: {str(e)}")
        return False

def test_onenote_access(access_token):
    """Test OneNote-specific API access"""
    print("\n📓 Testing OneNote API access...")
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    try:
        # Get OneNote notebooks
        response = requests.get(
            'https://graph.microsoft.com/v1.0/me/onenote/notebooks',
            headers=headers
        )
        
        if response.status_code == 200:
            notebooks = response.json()
            notebook_list = notebooks.get('value', [])
            
            print(f"✅ OneNote API access works!")
            print(f"   Found {len(notebook_list)} notebooks:")
            
            for i, notebook in enumerate(notebook_list[:5], 1):  # Show first 5
                print(f"   {i}. {notebook.get('displayName', 'Unnamed')}")
                
            if len(notebook_list) > 5:
                print(f"   ... and {len(notebook_list) - 5} more")
                
            return True
            
        else:
            print(f"❌ OneNote API access failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error accessing OneNote API: {str(e)}")
        return False

def main():
    """Run all tests"""
    print("🚀 OneNote Graph API Test Script")
    print("=" * 40)
    
    # Test authentication
    access_token = test_authentication()
    if not access_token:
        print("\n❌ Cannot proceed without authentication")
        return
    
    # Test Graph API
    if not test_graph_api(access_token):
        print("\n❌ Cannot proceed without Graph API access")
        return
    
    # Test OneNote API
    if not test_onenote_access(access_token):
        print("\n❌ OneNote API access failed")
        return
    
    print("\n🎉 All tests passed! Your Azure setup is working correctly!")
    print("\n📋 Next steps:")
    print("   1. Fix the Nix configuration indentation issues")
    print("   2. Add your client ID to the Nix config")
    print("   3. Run the full OneNote sync tool")

if __name__ == "__main__":
    main()
