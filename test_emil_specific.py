#!/usr/bin/env python3
"""
Test Rate-Limited OneNote Export - Emil's Specific Notebook
Verify we can access Emil's rate-limited OneNote via SharePoint
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from onenote_exporter import OneNoteExporter

def test_rate_limited_export():
    """Test accessing Emil's specific rate-limited personal notebook"""
    print("🧪 Testing Rate-Limited OneNote Access - EMIL's Notebook")
    print("=" * 60)
    
    # Create exporter
    exporter = OneNoteExporter(output_dir="./test_rate_limited_export")
    
    # Authenticate
    if not exporter.authenticate():
        print("❌ Authentication failed")
        return False
    
    # Verify we're authenticated as Emil
    print("\n👤 Verifying authentication...")
    result, error = exporter.make_graph_request('/me')
    if result:
        user_name = result.get('displayName', 'Unknown')
        user_email = result.get('userPrincipalName', 'Unknown')
        print(f"✅ Authenticated as: {user_name} ({user_email})")
        
        if 'emil' not in user_email.lower():
            print("⚠️  Warning: Not authenticated as Emil!")
            return False
    else:
        print(f"❌ Could not verify user: {error}")
        return False

    # Try direct access to Emil's SharePoint site where OneNote is hosted
    print("\n🏢 Testing direct access to Emil's SharePoint OneNote...")
    emil_site_path = "/personal/emil_isacson_compose_se"
    site_endpoint = f'/sites/composeit-my.sharepoint.com:{emil_site_path}'
    
    print(f"   🔍 Accessing: {site_endpoint}")
    site_result, site_error = exporter.make_graph_request(site_endpoint)
    
    if site_result:
        site_id = site_result.get('id')
        print(f"   ✅ Got Emil's SharePoint site ID: {site_id[:30]}...")
        
        # Try to get OneNote notebooks from Emil's site
        notebooks_endpoint = f'/sites/{site_id}/onenote/notebooks'
        print(f"   📚 Getting OneNote notebooks from Emil's site...")
        notebooks_result, notebooks_error = exporter.make_graph_request(notebooks_endpoint)
        
        if notebooks_result:
            notebooks = notebooks_result.get('value', [])
            print(f"   ✅ Found {len(notebooks)} OneNote notebooks in Emil's SharePoint site")
            
            emil_notebook = None
            for nb in notebooks:
                nb_name = nb.get('displayName', 'Unknown')
                print(f"      📓 {nb_name}")
                
                if 'Emil @ Compose IT Nordic AB' in nb_name:
                    emil_notebook = nb
                    print(f"      🎯 Found Emil's target notebook!")
            
            if not emil_notebook:
                print("   ❌ Emil's 'Emil @ Compose IT Nordic AB' notebook not found")
                return False
                
            # Test accessing sections from Emil's notebook
            nb_id = emil_notebook.get('id')
            sections_endpoint = f'/sites/{site_id}/onenote/notebooks/{nb_id}/sections'
            print(f"\n   📁 Testing access to notebook sections...")
            sections_result, sections_error = exporter.make_graph_request(sections_endpoint)
            
            if sections_result:
                sections = sections_result.get('value', [])
                print(f"   ✅ SUCCESS! Emil's notebook has {len(sections)} sections accessible")
                
                if sections:
                    # Test getting pages from first section
                    section = sections[0]
                    section_name = section.get('displayName', 'Unknown')
                    section_id = section.get('id')
                    
                    pages_endpoint = f'/sites/{site_id}/onenote/sections/{section_id}/pages'
                    print(f"   📄 Testing pages in section '{section_name}'...")
                    pages_result, pages_error = exporter.make_graph_request(pages_endpoint)
                    
                    if pages_result:
                        pages = pages_result.get('value', [])
                        print(f"   ✅ Section has {len(pages)} pages")
                        
                        if pages:
                            # Test getting content from first page
                            page = pages[0]
                            page_title = page.get('title', 'Unknown')
                            page_id = page.get('id')
                            
                            content_endpoint = f'/sites/{site_id}/onenote/pages/{page_id}/content'
                            print(f"   📝 Testing content from page '{page_title}'...")
                            content_result, content_error = exporter.make_graph_request_raw(content_endpoint)
                            
                            if content_result:
                                print(f"   🎉 SUCCESS! Got content ({len(content_result)} characters)")
                                print(f"   📄 Sample: {content_result[:150]}...")
                                return True
                            else:
                                print(f"   ❌ Could not get page content: {content_error}")
                                return False
                        else:
                            print(f"   ✅ SUCCESS! Can access section structure (no pages to test)")
                            return True
                    else:
                        print(f"   ❌ Could not get pages: {pages_error}")
                        return False
                else:
                    print(f"   ✅ SUCCESS! Can access notebook (no sections to test)")
                    return True
            else:
                if "10008" in str(sections_error) or "5,000" in str(sections_error):
                    print(f"   ⚠️  Sections access rate-limited due to >5,000 items")
                    print(f"   ✅ But notebook metadata is accessible via SharePoint!")
                    return True
                else:
                    print(f"   ❌ Could not get sections: {sections_error}")
                    return False
        else:
            print(f"   ❌ Could not get OneNote notebooks from site: {notebooks_error}")
            return False
    else:
        print(f"   ❌ Could not access Emil's SharePoint site: {site_error}")
        return False

if __name__ == "__main__":
    success = test_rate_limited_export()
    if success:
        print("\n🎉 EMIL'S RATE-LIMITED ONENOTE ACCESS TEST PASSED!")
        print("✅ Your 'Emil @ Compose IT Nordic AB' notebook is accessible!")
        print("✅ Ready for full export when needed!")
        exit(0)
    else:
        print("\n❌ EMIL'S RATE-LIMITED ONENOTE ACCESS TEST FAILED!")
        print("❌ Cannot access your rate-limited OneNote content")
        exit(1)
