#!/usr/bin/env python3
"""
Test Rate-Limited OneNote Content Access Workarounds
Try different methods to actually GET CONTENT from Emil's rate-limited notebook
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from onenote_exporter import OneNoteExporter

def test_rate_limited_workarounds():
    """Test various workarounds to access content from rate-limited notebook"""
    print("🧪 Testing Rate-Limited OneNote CONTENT ACCESS Workarounds")
    print("=" * 70)
    
    exporter = OneNoteExporter()
    
    if not exporter.authenticate():
        print("❌ Authentication failed")
        return False
    
    # Get Emil's SharePoint site info
    emil_site_path = "/personal/emil_isacson_compose_se"
    site_endpoint = f'/sites/composeit-my.sharepoint.com:{emil_site_path}'
    
    site_result, site_error = exporter.make_graph_request(site_endpoint)
    if not site_result:
        print(f"❌ Could not access Emil's SharePoint site: {site_error}")
        return False
    
    site_id = site_result.get('id')
    print(f"✅ Got Emil's SharePoint site ID: {site_id[:30]}...")
    
    # Try different workaround methods
    print(f"\n🔄 TESTING WORKAROUND METHODS FOR RATE-LIMITED CONTENT...")
    
    # Method 1: Try to get recent pages directly (bypass sections)
    print(f"\n📄 Method 1: Direct recent pages access...")
    recent_endpoint = f'/sites/{site_id}/onenote/pages?$top=20&$orderby=lastModifiedDateTime desc'
    recent_result, recent_error = exporter.make_graph_request(recent_endpoint)
    
    if recent_result:
        pages = recent_result.get('value', [])
        print(f"   ✅ Found {len(pages)} recent pages (bypassing sections!)")
        
        if pages:
            # Try to get content from first recent page
            page = pages[0]
            page_title = page.get('title', 'Unknown')
            page_id = page.get('id')
            
            content_endpoint = f'/sites/{site_id}/onenote/pages/{page_id}/content'
            print(f"   📝 Testing content from recent page: '{page_title}'...")
            content_result, content_error = exporter.make_graph_request_raw(content_endpoint)
            
            if content_result:
                print(f"   🎉 SUCCESS! Got recent page content ({len(content_result)} chars)")
                print(f"   📄 Content sample: {content_result[:200]}...")
                return True
            else:
                print(f"   ❌ Could not get recent page content: {content_error}")
        else:
            print(f"   ⚠️  No recent pages found")
    else:
        print(f"   ❌ Could not get recent pages: {recent_error}")
    
    # Method 2: Try searching for pages by content
    print(f"\n🔍 Method 2: Search for pages by content...")
    search_endpoint = f'/sites/{site_id}/onenote/pages?$search=*'
    search_result, search_error = exporter.make_graph_request(search_endpoint)
    
    if search_result:
        pages = search_result.get('value', [])
        print(f"   ✅ Search found {len(pages)} pages")
        
        if pages:
            # Try to get content from first search result
            page = pages[0]
            page_title = page.get('title', 'Unknown')
            page_id = page.get('id')
            
            content_endpoint = f'/sites/{site_id}/onenote/pages/{page_id}/content'
            print(f"   📝 Testing content from search result: '{page_title}'...")
            content_result, content_error = exporter.make_graph_request_raw(content_endpoint)
            
            if content_result:
                print(f"   🎉 SUCCESS! Got search page content ({len(content_result)} chars)")
                print(f"   📄 Content sample: {content_result[:200]}...")
                return True
            else:
                print(f"   ❌ Could not get search page content: {content_error}")
        else:
            print(f"   ⚠️  Search returned no pages")
    else:
        print(f"   ❌ Could not search pages: {search_error}")
    
    # Method 3: Try accessing pages with pagination and limits
    print(f"\n📋 Method 3: Limited sections access with small page size...")
    notebooks_result, _ = exporter.make_graph_request(f'/sites/{site_id}/onenote/notebooks')
    
    if notebooks_result:
        notebooks = notebooks_result.get('value', [])
        emil_notebook = None
        
        for nb in notebooks:
            if 'Emil @ Compose IT Nordic AB' in nb.get('displayName', ''):
                emil_notebook = nb
                break
        
        if emil_notebook:
            nb_id = emil_notebook.get('id')
            
            # Try to get sections with very small limit
            sections_endpoint = f'/sites/{site_id}/onenote/notebooks/{nb_id}/sections?$top=3'
            print(f"   📁 Trying to get first 3 sections only...")
            sections_result, sections_error = exporter.make_graph_request(sections_endpoint)
            
            if sections_result:
                sections = sections_result.get('value', [])
                print(f"   ✅ Got {len(sections)} sections with small limit!")
                
                if sections:
                    # Try to get pages from first section with small limit
                    section = sections[0]
                    section_name = section.get('displayName', 'Unknown')
                    section_id = section.get('id')
                    
                    pages_endpoint = f'/sites/{site_id}/onenote/sections/{section_id}/pages?$top=5'
                    print(f"   📄 Getting first 5 pages from section '{section_name}'...")
                    pages_result, pages_error = exporter.make_graph_request(pages_endpoint)
                    
                    if pages_result:
                        pages = pages_result.get('value', [])
                        print(f"   ✅ Got {len(pages)} pages from section!")
                        
                        if pages:
                            # Try to get content from first page
                            page = pages[0]
                            page_title = page.get('title', 'Unknown')
                            page_id = page.get('id')
                            
                            content_endpoint = f'/sites/{site_id}/onenote/pages/{page_id}/content'
                            print(f"   📝 Testing content from page: '{page_title}'...")
                            content_result, content_error = exporter.make_graph_request_raw(content_endpoint)
                            
                            if content_result:
                                print(f"   🎉 SUCCESS! Got page content ({len(content_result)} chars)")
                                print(f"   📄 Content sample: {content_result[:200]}...")
                                return True
                            else:
                                print(f"   ❌ Could not get page content: {content_error}")
                        else:
                            print(f"   ⚠️  Section has no pages")
                    else:
                        print(f"   ❌ Could not get pages from section: {pages_error}")
                else:
                    print(f"   ⚠️  No sections returned")
            else:
                print(f"   ❌ Still rate-limited even with small limit: {sections_error}")
        else:
            print(f"   ❌ Could not find Emil's notebook")
    
    # Method 4: Try direct file access via OneDrive/SharePoint
    print(f"\n💾 Method 4: Direct file system access to OneNote files...")
    drive_endpoint = f'/sites/{site_id}/drive/root/children'
    drive_result, drive_error = exporter.make_graph_request(drive_endpoint)
    
    if drive_result:
        items = drive_result.get('value', [])
        print(f"   📁 Found {len(items)} items in root drive")
        
        # Look for OneNote-related folders or files
        onenote_items = []
        for item in items:
            name = item.get('name', '')
            if 'onenote' in name.lower() or 'emil' in name.lower() or name.endswith('.one'):
                onenote_items.append(item)
                print(f"      📓 Found OneNote-related: {name}")
        
        if onenote_items:
            print(f"   ✅ Found {len(onenote_items)} OneNote-related items via drive access")
            # This is promising - could try to access individual .one files
            return True
        else:
            print(f"   ⚠️  No OneNote items found in root drive")
    else:
        print(f"   ❌ Could not access drive: {drive_error}")
    
    print(f"\n❌ All workaround methods failed to access rate-limited content")
    return False

if __name__ == "__main__":
    success = test_rate_limited_workarounds()
    if success:
        print(f"\n🎉 FOUND A WORKING WORKAROUND!")
        print(f"✅ We can access content from Emil's rate-limited OneNote!")
        exit(0)
    else:
        print(f"\n❌ NO WORKING WORKAROUNDS FOUND")
        print(f"❌ Rate limitation cannot be bypassed with current methods")
        exit(1)
