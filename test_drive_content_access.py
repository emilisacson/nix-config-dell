#!/usr/bin/env python3
"""
Test accessing Emil's OneNote content via the working drive access method
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from onenote_exporter import OneNoteExporter

def test_drive_content_access():
    """Test getting actual content from Emil's OneNote via drive access"""
    print("🧪 Testing Drive Access Content Extraction")
    print("=" * 50)
    
    exporter = OneNoteExporter()
    
    if not exporter.authenticate():
        print("❌ Authentication failed")
        return False
    
    # Get Emil's SharePoint site
    emil_site_path = "/personal/emil_isacson_compose_se"
    site_endpoint = f'/sites/composeit-my.sharepoint.com:{emil_site_path}'
    
    site_result, site_error = exporter.make_graph_request(site_endpoint)
    if not site_result:
        print(f"❌ Could not access site: {site_error}")
        return False
    
    site_id = site_result.get('id')
    print(f"✅ Got site ID: {site_id[:30]}...")
    
    # Get drive items
    drive_endpoint = f'/sites/{site_id}/drive/root/children'
    drive_result, drive_error = exporter.make_graph_request(drive_endpoint)
    
    if not drive_result:
        print(f"❌ Could not access drive: {drive_error}")
        return False
    
    items = drive_result.get('value', [])
    print(f"✅ Found {len(items)} drive items")
    
    # Find Emil's OneNote
    emil_onenote = None
    for item in items:
        name = item.get('name', '')
        if 'Emil @ Compose IT Nordic AB' in name:
            emil_onenote = item
            print(f"🎯 Found Emil's OneNote: {name}")
            break
    
    if not emil_onenote:
        print("❌ Could not find Emil's OneNote in drive")
        return False
    
    # Get details about the OneNote item
    item_id = emil_onenote.get('id')
    item_type = emil_onenote.get('folder') or emil_onenote.get('file')
    web_url = emil_onenote.get('webUrl', '')
    
    print(f"📋 OneNote item details:")
    print(f"   ID: {item_id}")
    print(f"   Type: {'Folder' if emil_onenote.get('folder') else 'File'}")
    print(f"   Web URL: {web_url}")
    
    # If it's a folder, explore its contents
    if emil_onenote.get('folder'):
        print(f"\n📁 Exploring OneNote folder contents...")
        children_endpoint = f'/sites/{site_id}/drive/items/{item_id}/children'
        children_result, children_error = exporter.make_graph_request(children_endpoint)
        
        if children_result:
            children = children_result.get('value', [])
            print(f"   ✅ Found {len(children)} items in OneNote folder")
            
            # Show first few items
            for i, child in enumerate(children[:10]):
                child_name = child.get('name', 'Unknown')
                child_type = 'Folder' if child.get('folder') else 'File'
                print(f"      {i+1}. {child_name} ({child_type})")
            
            # Try to access first OneNote section/file
            if children:
                first_child = children[0]
                child_id = first_child.get('id')
                child_name = first_child.get('name', 'Unknown')
                
                print(f"\n🔍 Testing access to first item: '{child_name}'...")
                
                # If it's a file, try to get its content
                if first_child.get('file'):
                    # Try different ways to access OneNote file content
                    
                    # Method A: Direct content access
                    content_endpoint = f'/sites/{site_id}/drive/items/{child_id}/content'
                    print(f"   📄 Method A: Direct file content...")
                    content_result, content_error = exporter.make_graph_request_raw(content_endpoint)
                    
                    if content_result:
                        print(f"   ✅ Got file content ({len(content_result)} bytes)")
                        # Check if it's HTML or binary
                        if content_result.startswith(('<html', '<!DOCTYPE')):
                            print(f"   📝 Content is HTML: {content_result[:200]}...")
                            return True
                        else:
                            print(f"   📦 Content is binary OneNote format")
                            return True
                    else:
                        print(f"   ❌ Could not get file content: {content_error}")
                    
                    # Method B: Try OneNote-specific access for this file
                    # Get the file's OneNote-specific ID if possible
                    print(f"   📄 Method B: OneNote API via file...")
                    
                    # Check if we can derive OneNote page/section IDs from the file
                    # This would require understanding the relationship between drive files and OneNote entities
                    
                # If it's a folder, explore deeper
                elif first_child.get('folder'):
                    print(f"   📁 First item is a folder, exploring deeper...")
                    grandchildren_endpoint = f'/sites/{site_id}/drive/items/{child_id}/children'
                    grandchildren_result, grandchildren_error = exporter.make_graph_request(grandchildren_endpoint)
                    
                    if grandchildren_result:
                        grandchildren = grandchildren_result.get('value', [])
                        print(f"      ✅ Found {len(grandchildren)} items in subfolder")
                        
                        for gc in grandchildren[:5]:
                            gc_name = gc.get('name', 'Unknown')
                            gc_type = 'Folder' if gc.get('folder') else 'File'
                            print(f"         • {gc_name} ({gc_type})")
                        
                        return True
                    else:
                        print(f"      ❌ Could not access subfolder: {grandchildren_error}")
        else:
            print(f"   ❌ Could not get folder contents: {children_error}")
    
    # If it's a file, try to access it directly
    elif emil_onenote.get('file'):
        print(f"\n📄 OneNote is a file, trying direct access...")
        content_endpoint = f'/sites/{site_id}/drive/items/{item_id}/content'
        content_result, content_error = exporter.make_graph_request_raw(content_endpoint)
        
        if content_result:
            print(f"   ✅ Got OneNote file content ({len(content_result)} bytes)")
            return True
        else:
            print(f"   ❌ Could not get file content: {content_error}")
    
    return False

if __name__ == "__main__":
    success = test_drive_content_access()
    if success:
        print(f"\n🎉 SUCCESS! Can access Emil's OneNote content via drive!")
        exit(0)
    else:
        print(f"\n❌ Could not access OneNote content via drive")
        exit(1)
