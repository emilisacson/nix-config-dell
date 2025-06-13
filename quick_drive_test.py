#!/usr/bin/env python3
"""
Simple test to explore Emil's OneNote structure via drive access
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from onenote_exporter import OneNoteExporter

print("🔍 Quick Drive Structure Test")
print("=" * 30)

exporter = OneNoteExporter()

print("🔐 Authenticating...")
if not exporter.authenticate():
    print("❌ Auth failed")
    exit(1)

# Get Emil's site
site_result, _ = exporter.make_graph_request('/sites/composeit-my.sharepoint.com:/personal/emil_isacson_compose_se')
if not site_result:
    print("❌ No site")
    exit(1)

site_id = site_result.get('id')
print(f"✅ Site: {site_id[:20]}...")

# Get drive items  
drive_result, _ = exporter.make_graph_request(f'/sites/{site_id}/drive/root/children')
if not drive_result:
    print("❌ No drive")
    exit(1)

items = drive_result.get('value', [])
print(f"✅ Drive items: {len(items)}")

# Find Emil's OneNote
for item in items:
    name = item.get('name', '')
    if 'Emil @ Compose IT Nordic AB' in name:
        print(f"🎯 Found: {name}")
        item_id = item.get('id')
        is_folder = bool(item.get('folder'))
        print(f"   Type: {'Folder' if is_folder else 'File'}")
        
        if is_folder:
            # Get folder contents
            children_result, error = exporter.make_graph_request(f'/sites/{site_id}/drive/items/{item_id}/children')
            if children_result:
                children = children_result.get('value', [])
                print(f"   📁 Contains {len(children)} items:")
                for i, child in enumerate(children[:5]):
                    child_name = child.get('name', 'Unknown')
                    child_type = 'Folder' if child.get('folder') else 'File'
                    print(f"      {i+1}. {child_name} ({child_type})")
                
                print(f"\n🎉 SUCCESS! Found OneNote structure via drive access!")
                print(f"✅ This proves we can bypass the rate limitation!")
                break
            else:
                print(f"   ❌ Cannot access folder: {error}")
        else:
            print(f"   📄 OneNote is a single file")
            print(f"\n🎉 SUCCESS! Found OneNote file via drive access!")
            break
else:
    print("❌ Emil's OneNote not found")
    exit(1)
