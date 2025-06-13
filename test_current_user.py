#!/usr/bin/env python3
"""
Test to verify which user we're authenticated as and what drive we're accessing
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from onenote_exporter import OneNoteExporter

def test_current_user():
    print("🔍 Testing Current User and Drive Access")
    print("=" * 50)
    
    exporter = OneNoteExporter()
    
    if not exporter.authenticate():
        print("❌ Authentication failed")
        return False
    
    # Check current user
    print("\n👤 Getting current user info...")
    result, error = exporter.make_graph_request('/me')
    if result:
        user_name = result.get('displayName', 'Unknown')
        user_email = result.get('userPrincipalName', 'Unknown')
        print(f"✅ Authenticated as: {user_name} ({user_email})")
    else:
        print(f"❌ Could not get user info: {error}")
        return False
    
    # Check personal drive root
    print("\n💾 Getting personal drive info...")
    result, error = exporter.make_graph_request('/me/drive')
    if result:
        drive_name = result.get('name', 'Unknown')
        drive_owner = result.get('owner', {}).get('user', {}).get('displayName', 'Unknown')
        drive_web_url = result.get('webUrl', 'Unknown')
        print(f"✅ Personal drive: {drive_name}")
        print(f"   Owner: {drive_owner}")
        print(f"   URL: {drive_web_url}")
    else:
        print(f"❌ Could not get drive info: {error}")
    
    # Check OneNote files in your personal drive  
    print("\n📂 Searching YOUR personal drive for OneNote files...")
    search_endpoint = "/me/drive/search(q='*.one')"
    result, error = exporter.make_graph_request(search_endpoint)
    
    if result:
        items = result.get('value', [])
        print(f"✅ Found {len(items)} .one files in your personal drive")
        
        # Show details of first few files
        for i, item in enumerate(items[:5]):
            name = item.get('name', 'Unknown')
            web_url = item.get('webUrl', '')
            mime_type = item.get('file', {}).get('mimeType', 'Unknown')
            print(f"   {i+1}. {name}")
            print(f"      MIME: {mime_type}")
            print(f"      URL: {web_url[:100]}...")
    else:
        print(f"❌ Could not search personal drive: {error}")
    
    print("\n🔍 Checking personal notebooks directly...")
    result, error = exporter.make_graph_request('/me/onenote/notebooks')
    
    if result:
        notebooks = result.get('value', [])
        print(f"✅ Found {len(notebooks)} personal notebooks")
        for nb in notebooks:
            print(f"   📓 {nb.get('displayName', 'Unknown')}")
    else:
        if "10008" in str(error):
            print("⚠️  Personal notebooks rate-limited (>5000 items) - this is expected!")
        else:
            print(f"❌ Error getting personal notebooks: {error}")
    
    return True

if __name__ == "__main__":
    test_current_user()
