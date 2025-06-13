#!/usr/bin/env python3
"""
Detailed OneNote Access Test Script
Check all possible OneNote access patterns including shared notebooks
"""

import json
import requests
import random
from msal import PublicClientApplication

# CONFIGURE THESE VALUES
CLIENT_ID = "8a52ee61-c61a-4873-bfc6-489fa574e92c"
TENANT_ID = "d8fe6df3-c89e-4fa6-a2f8-cfcc31dffb1c"

def test_authentication():
    """Test authentication with Microsoft Graph"""
    print("🔐 Testing Authentication...")
    print(f"Client ID: {CLIENT_ID}")
    print(f"Tenant ID: {TENANT_ID}")
    print()
    
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
            scopes=["User.Read", "Notes.Read.All", "Notes.ReadWrite.All", "Sites.Read.All", "Files.Read.All", "Team.ReadBasic.All", "Channel.ReadBasic.All"],
            account=accounts[0]
        )
    else:
        result = None
    
    # If no cached token, get new one interactively
    if not result:
        print("🌐 Opening browser for authentication...")
        result = app.acquire_token_interactive(
            scopes=["User.Read", "Notes.Read.All", "Notes.ReadWrite.All", "Sites.Read.All", "Files.Read.All", "Team.ReadBasic.All", "Channel.ReadBasic.All"]
        )
    
    if "access_token" in result:
        print("✅ Authentication successful!")
        return result["access_token"]
    else:
        print(f"❌ Authentication failed: {result.get('error_description', 'Unknown error')}")
        return None

def make_graph_request(access_token, endpoint, description=""):
    """Make authenticated request to Microsoft Graph"""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    url = f'https://graph.microsoft.com/v1.0{endpoint}'
    
    try:
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            return response.json(), None
        else:
            error_msg = f"{response.status_code} - {response.text}"
            return None, error_msg
            
    except Exception as e:
        return None, str(e)

def make_graph_request_raw(access_token, endpoint):
    """Make authenticated request to Microsoft Graph for raw content (like OneNote page content)"""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Accept': 'text/html'  # OneNote content is HTML
    }
    
    url = f'https://graph.microsoft.com/v1.0{endpoint}'
    
    try:
        response = requests.get(url, headers=headers)
        
        if response.status_code == 200:
            return response.text, None
        else:
            error_msg = f"{response.status_code} - {response.text}"
            return None, error_msg
            
    except Exception as e:
        return None, str(e)

def make_graph_request_with_pagination(access_token, endpoint, max_pages=10):
    """Make authenticated request to Microsoft Graph with pagination support"""
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'application/json'
    }
    
    all_items = []
    url = f'https://graph.microsoft.com/v1.0{endpoint}'
    page_count = 0
    
    while url and page_count < max_pages:
        try:
            response = requests.get(url, headers=headers)
            
            if response.status_code == 200:
                data = response.json()
                items = data.get('value', [])
                all_items.extend(items)
                
                # Check for next page
                url = data.get('@odata.nextLink')
                page_count += 1
                
                if url:
                    print(f"      📄 Retrieved page {page_count} ({len(items)} items), continuing...")
                else:
                    print(f"      📄 Retrieved page {page_count} ({len(items)} items), finished")
                    
            else:
                error_msg = f"{response.status_code} - {response.text}"
                return None, error_msg
                
        except Exception as e:
            return None, str(e)
    
    if page_count >= max_pages and url:
        print(f"      ⚠️  Stopped after {max_pages} pages, more data available")
    
    return {'value': all_items, 'total_pages': page_count}, None

def test_basic_onenote_access(access_token):
    """Test basic OneNote access (user's own notebooks)"""
    print("\n📓 Testing Basic OneNote Access (/me/onenote/notebooks)...")
    
    result, error = make_graph_request(access_token, '/me/onenote/notebooks')
    
    if result:
        notebooks = result.get('value', [])
        print(f"✅ Found {len(notebooks)} personal notebooks:")
        
        for i, notebook in enumerate(notebooks, 1):
            print(f"   {i}. {notebook.get('displayName', 'Unnamed')}")
            print(f"      ID: {notebook.get('id', 'Unknown')}")
            print(f"      Owner: {notebook.get('createdBy', {}).get('user', {}).get('displayName', 'Unknown')}")
            if 'links' in notebook:
                print(f"      Web URL: {notebook.get('links', {}).get('oneNoteWebUrl', {}).get('href', 'N/A')}")
            print()
        
        return notebooks
    else:
        print(f"❌ Failed: {error}")
        return []

def test_shared_notebooks_via_groups(access_token):
    """Test access to notebooks via groups/teams (without Group.Read.All)"""
    print("\n👥 Testing Shared Notebooks via Groups...")
    print("   ⚠️  Note: Without Group.Read.All permission, we can't enumerate all groups")
    print("   ℹ️  Trying alternative approaches...")
    
    # Try to get user's joined teams (this might work with limited permissions)
    result, error = make_graph_request(access_token, '/me/joinedTeams')
    
    if result:
        teams = result.get('value', [])
        print(f"📋 Found {len(teams)} joined teams:")
        
        all_team_notebooks = []
        
        for team in teams[:5]:  # Check first 5 teams
            team_name = team.get('displayName', 'Unknown')
            team_id = team.get('id')
            
            print(f"   🏢 {team_name}")
            
            if team_id:
                # Try to get OneNote notebooks for this team
                endpoint = f'/teams/{team_id}/channels'
                channels_result, channels_error = make_graph_request(access_token, endpoint)
                
                if channels_result:
                    channels = channels_result.get('value', [])
                    print(f"      📺 Found {len(channels)} channels")
                    
                    # Check each channel for OneNote tabs
                    for channel in channels:
                        channel_id = channel.get('id')
                        channel_name = channel.get('displayName', 'Unknown')
                        
                        if channel_id:
                            tabs_endpoint = f'/teams/{team_id}/channels/{channel_id}/tabs'
                            tabs_result, tabs_error = make_graph_request(access_token, tabs_endpoint)
                            
                            if tabs_result:
                                tabs = tabs_result.get('value', [])
                                onenote_tabs = [tab for tab in tabs if 'onenote' in tab.get('teamsApp', {}).get('id', '').lower()]
                                
                                if onenote_tabs:
                                    print(f"         📓 Channel '{channel_name}' has {len(onenote_tabs)} OneNote tabs")
                                    for tab in onenote_tabs:
                                        print(f"            - {tab.get('displayName', 'Unnamed OneNote')}")
                else:
                    print(f"      ❌ Could not access team channels: {channels_error}")
        
        return all_team_notebooks
    else:
        print(f"❌ Could not get joined teams: {error}")
        return []

def test_sharepoint_onenote_access(access_token):
    """Test access to OneNote via SharePoint sites"""
    print("\n🌐 Testing OneNote via SharePoint Sites...")
    
    # Get sites the user has access to (with pagination)
    result, error = make_graph_request_with_pagination(access_token, '/me/followedSites', max_pages=5)
    
    if not result:
        print(f"❌ Could not get SharePoint sites: {error}")
        return []
    
    sites = result.get('value', [])
    total_pages = result.get('total_pages', 1)
    print(f"📋 Found {len(sites)} followed SharePoint sites across {total_pages} pages:")
    
    all_site_notebooks = []
    
    for site in sites[:10]:  # Check first 10 sites
        site_name = site.get('displayName', 'Unknown')
        site_id = site.get('id')
        
        print(f"   🌐 {site_name}")
        
        if site_id:
            # Try to get OneNote notebooks for this site
            endpoint = f'/sites/{site_id}/onenote/notebooks'
            result, error = make_graph_request(access_token, endpoint)
            
            if result:
                site_notebooks = result.get('value', [])
                if site_notebooks:
                    print(f"      📓 Found {len(site_notebooks)} notebooks:")
                    for notebook in site_notebooks:
                        print(f"         - {notebook.get('displayName', 'Unnamed')}")
                        all_site_notebooks.append({
                            'notebook': notebook,
                            'site': site_name,
                            'site_id': site_id
                        })
                else:
                    print(f"      📭 No notebooks in this site")
            else:
                print(f"      ❌ Could not access notebooks: {error}")
    
    return all_site_notebooks

def test_onenote_via_drive_search(access_token):
    """Try to find OneNote files via OneDrive/SharePoint search"""
    print("\n🔍 Searching for OneNote files via Drive API...")
    
    # Search for OneNote files in user's drives using broad patterns first
    search_queries = [
        "*.one",  # OneNote files
        "*.onetoc2",  # OneNote table of contents
        "name:OneNote",  # Files/folders named OneNote
    ]
    
    # OneNote MIME types to filter by
    onenote_mime_types = [
        'application/msonenote',
        'application/onenote',
        'application/x-msonenote',
        'application/vnd.ms-onenote'
    ]
    
    all_found_notebooks = []
    
    for query in search_queries:
        print(f"   🔎 Searching for: {query}")
        
        # Try searching in user's drive with pagination
        endpoint = f"/me/drive/search(q='{query}')"
        result, error = make_graph_request_with_pagination(access_token, endpoint, max_pages=20)
        
        if result:
            items = result.get('value', [])
            total_pages = result.get('total_pages', 1)
            print(f"      📋 Found {len(items)} total items across {total_pages} pages, filtering by OneNote MIME types...")
            
            # Filter by OneNote MIME types
            onenote_items = []
            for item in items:
                file_type = item.get('file', {}).get('mimeType', '')
                if file_type in onenote_mime_types:
                    onenote_items.append(item)
            
            print(f"      ✅ Found {len(onenote_items)} OneNote files (filtered by MIME type)")
            
            for item in onenote_items:
                name = item.get('name', 'Unknown')
                web_url = item.get('webUrl', 'No URL')
                file_type = item.get('file', {}).get('mimeType', 'Unknown type')
                
                print(f"         📓 {name}")
                print(f"            MIME Type: {file_type}")
                print(f"            URL: {web_url}")
                
                all_found_notebooks.append({
                    'name': name,
                    'url': web_url,
                    'type': file_type,
                    'source': 'drive_search'
                })
                
            # Also show some examples of non-OneNote files found for debugging
            if len(items) > len(onenote_items):
                non_onenote_count = len(items) - len(onenote_items)
                print(f"      ℹ️  Filtered out {non_onenote_count} non-OneNote files")
                print(f"         Example MIME types found: ", end="")
                other_types = set()
                for item in items:
                    if item not in onenote_items:
                        mime_type = item.get('file', {}).get('mimeType', 'unknown')
                        other_types.add(mime_type)
                        if len(other_types) >= 3:  # Show first 3 different types
                            break
                print(", ".join(list(other_types)[:3]))
        else:
            print(f"      ❌ Search failed: {error}")
    
    return all_found_notebooks
    
    return all_found_notebooks

def test_recent_files_for_onenote(access_token):
    """Check recent files for OneNote content"""
    print("\n⏰ Checking Recent Files for OneNote...")
    
    endpoint = "/me/insights/used"
    result, error = make_graph_request(access_token, endpoint)
    
    if result:
        items = result.get('value', [])
        onenote_items = []
        
        print(f"📋 Checking {len(items)} recent items...")
        
        for item in items:
            resource = item.get('resource', {})
            name = resource.get('displayName', resource.get('name', 'Unknown'))
            web_url = resource.get('webUrl', '')
            
            # Check if it's OneNote related
            if any(keyword in name.lower() for keyword in ['onenote', '.one']) or 'onenote' in web_url.lower():
                print(f"   📓 Found OneNote item: {name}")
                print(f"      URL: {web_url}")
                onenote_items.append({
                    'name': name,
                    'url': web_url,
                    'source': 'recent_files'
                })
        
        if not onenote_items:
            print("   📭 No OneNote items found in recent files")
            
        return onenote_items
    else:
        print(f"❌ Could not get recent files: {error}")
        return []

def test_alternative_endpoints(access_token):
    """Test alternative Graph API endpoints for OneNote"""
    print("\n🔍 Testing Alternative OneNote Endpoints...")
    
    endpoints = [
        ('/me/onenote/notebooks?$expand=sections', 'Personal notebooks with sections'),
        ('/me/drives?$filter=driveType eq \'business\'', 'Business drives (may contain OneNote)'),
        ('/me/insights/shared', 'Shared documents (may include OneNote)'),
    ]
    
    for endpoint, description in endpoints:
        print(f"\n   🔗 Testing: {description}")
        print(f"      Endpoint: {endpoint}")
        
        result, error = make_graph_request(access_token, endpoint)
        
        if result:
            items = result.get('value', [])
            print(f"      ✅ Success: Found {len(items)} items")
            
            # Show first few items
            for item in items[:3]:
                name = item.get('displayName') or item.get('name') or 'Unknown'
                print(f"         - {name}")
                
        else:
            print(f"      ❌ Failed: {error}")
    """Test alternative Graph API endpoints for OneNote"""
    print("\n🔍 Testing Alternative OneNote Endpoints...")
    
    endpoints = [
        ('/me/onenote/notebooks?$expand=sections', 'Personal notebooks with sections'),
        ('/me/drives?$filter=driveType eq \'business\'', 'Business drives (may contain OneNote)'),
        ('/me/insights/shared', 'Shared documents (may include OneNote)'),
    ]
    
    for endpoint, description in endpoints:
        print(f"\n   🔗 Testing: {description}")
        print(f"      Endpoint: {endpoint}")
        
        result, error = make_graph_request(access_token, endpoint)
        
        if result:
            items = result.get('value', [])
            print(f"      ✅ Success: Found {len(items)} items")
            
            # Show first few items
            for item in items[:3]:
                name = item.get('displayName') or item.get('name') or 'Unknown'
                print(f"         - {name}")
                
        else:
            print(f"      ❌ Failed: {error}")

def test_reading_notebook_content(access_token, personal_notebooks, site_notebooks):
    """Test actually reading content from ALL discovered notebooks - 5 random pages from each"""
    print("\n📖 Testing Reading Notebook Content (Comprehensive Test)...")
    
    content_results = {
        'accessible': [],
        'restricted': [],
        'failed': [],
        'notebooks_tested': 0,
        'total_pages_found': 0,
        'total_pages_tested': 0
    }
    
    def get_all_pages_from_notebook(access_token, notebook_id, site_id=None, notebook_name="Unknown"):
        """Get all pages from all sections in a notebook"""
        all_pages = []
        
        # Determine the correct endpoint based on whether it's personal or SharePoint
        if site_id:
            sections_endpoint = f'/sites/{site_id}/onenote/notebooks/{notebook_id}/sections'
        else:
            sections_endpoint = f'/me/onenote/notebooks/{notebook_id}/sections'
        
        # Get all sections
        result, error = make_graph_request(access_token, sections_endpoint)
        
        if result:
            sections = result.get('value', [])
            print(f"         ✅ Found {len(sections)} sections")
            
            for section in sections:
                section_name = section.get('displayName', 'Unnamed Section')
                section_id = section.get('id')
                
                if section_id:
                    # Get pages from this section
                    if site_id:
                        pages_endpoint = f'/sites/{site_id}/onenote/sections/{section_id}/pages'
                    else:
                        pages_endpoint = f'/me/onenote/sections/{section_id}/pages'
                    
                    pages_result, pages_error = make_graph_request(access_token, pages_endpoint)
                    
                    if pages_result:
                        pages = pages_result.get('value', [])
                        print(f"            📄 Section '{section_name}': {len(pages)} pages")
                        
                        for page in pages:
                            all_pages.append({
                                'page_data': page,
                                'section_name': section_name,
                                'section_id': section_id,
                                'site_id': site_id
                            })
                    else:
                        print(f"            ❌ Failed to get pages from section '{section_name}': {pages_error}")
        else:
            return [], error
        
        return all_pages, None
    
    def test_page_content(access_token, page_info, notebook_name):
        """Test reading content from a specific page"""
        page_data = page_info['page_data']
        section_name = page_info['section_name']
        site_id = page_info['site_id']
        
        page_title = page_data.get('title', 'Untitled Page')
        page_id = page_data.get('id')
        
        print(f"            📝 Testing page: {page_title}")
        
        # Determine correct endpoint
        if site_id:
            content_endpoint = f'/sites/{site_id}/onenote/pages/{page_id}/content'
        else:
            content_endpoint = f'/me/onenote/pages/{page_id}/content'
        
        content_result, content_error = make_graph_request_raw(access_token, content_endpoint)
        
        if content_result:
            content_length = len(content_result)
            print(f"               ✅ Successfully read {content_length} characters of HTML content")
            # Show a brief preview
            preview = content_result[:80].replace('\n', ' ').replace('\r', ' ')
            print(f"               📄 Preview: {preview}...")
            
            return {
                'notebook': notebook_name,
                'section': section_name,
                'page': page_title,
                'content_length': content_length,
                'type': 'sharepoint' if site_id else 'personal',
                'site': page_info.get('site_name', 'Personal')
            }
        else:
            print(f"               ❌ Failed to read page content: {content_error}")
            return {
                'notebook': notebook_name,
                'section': section_name,
                'page': page_title,
                'error': content_error,
                'type': 'sharepoint' if site_id else 'personal',
                'site': page_info.get('site_name', 'Personal')
            }
    
    # Test reading from personal notebooks
    print("\n   📓 Testing Personal Notebooks...")
    for notebook in personal_notebooks:
        notebook_name = notebook.get('displayName', 'Unknown')
        notebook_id = notebook.get('id')
        
        print(f"      🔍 Testing: {notebook_name}")
        content_results['notebooks_tested'] += 1
        
        if notebook_id:
            all_pages, error = get_all_pages_from_notebook(access_token, notebook_id, None, notebook_name)
            
            if error:
                print(f"         ❌ Failed to get pages: {error}")
                if "5,000" in str(error):
                    print(f"         ⚠️  Rate limited due to too many items")
                    content_results['restricted'].append({
                        'notebook': notebook_name,
                        'error': 'Rate limited (>5000 items)',
                        'type': 'personal'
                    })
            else:
                content_results['total_pages_found'] += len(all_pages)
                print(f"         📊 Total pages found: {len(all_pages)}")
                
                if all_pages:
                    # Sample up to 5 random pages
                    sample_size = min(5, len(all_pages))
                    sampled_pages = random.sample(all_pages, sample_size)
                    content_results['total_pages_tested'] += len(sampled_pages)
                    
                    print(f"         🎲 Testing {sample_size} random pages...")
                    
                    for page_info in sampled_pages:
                        result = test_page_content(access_token, page_info, notebook_name)
                        if 'error' in result:
                            content_results['failed'].append(result)
                        else:
                            content_results['accessible'].append(result)
    
    # Test reading from SharePoint notebooks (ALL of them)
    print("\n   🌐 Testing SharePoint Notebooks (ALL notebooks)...")
    for site_notebook in site_notebooks:  # Test ALL SharePoint notebooks
        notebook = site_notebook['notebook']
        site_name = site_notebook['site']
        site_id = site_notebook['site_id']
        notebook_name = notebook.get('displayName', 'Unknown')
        notebook_id = notebook.get('id')
        
        print(f"      🔍 Testing: {notebook_name} (from {site_name})")
        content_results['notebooks_tested'] += 1
        
        if notebook_id and site_id:
            all_pages, error = get_all_pages_from_notebook(access_token, notebook_id, site_id, notebook_name)
            
            if error:
                print(f"         ❌ Failed to get pages: {error}")
                content_results['failed'].append({
                    'notebook': notebook_name,
                    'error': error,
                    'type': 'sharepoint',
                    'site': site_name
                })
            else:
                content_results['total_pages_found'] += len(all_pages)
                print(f"         📊 Total pages found: {len(all_pages)}")
                
                if all_pages:
                    # Sample up to 5 random pages
                    sample_size = min(5, len(all_pages))
                    sampled_pages = random.sample(all_pages, sample_size)
                    content_results['total_pages_tested'] += len(sampled_pages)
                    
                    print(f"         🎲 Testing {sample_size} random pages...")
                    
                    for page_info in sampled_pages:
                        page_info['site_name'] = site_name  # Add site name for context
                        result = test_page_content(access_token, page_info, notebook_name)
                        if 'error' in result:
                            content_results['failed'].append(result)
                        else:
                            content_results['accessible'].append(result)
                else:
                    print(f"         📭 No pages found in notebook")
    
    # Print comprehensive content reading summary
    print(f"\n   📊 Comprehensive Content Reading Summary:")
    print(f"      📓 Notebooks tested: {content_results['notebooks_tested']}")
    print(f"      📄 Total pages discovered: {content_results['total_pages_found']}")
    print(f"      🎲 Pages tested (sampled): {content_results['total_pages_tested']}")
    print(f"      ✅ Successfully read content: {len(content_results['accessible'])}")
    print(f"      🚫 Rate limited/restricted: {len(content_results['restricted'])}")
    print(f"      ❌ Failed to read: {len(content_results['failed'])}")
    
    if content_results['accessible']:
        print(f"\n   📖 Sample of Readable Content:")
        for item in content_results['accessible'][:5]:  # Show first 5 examples
            print(f"      • {item['notebook']} > {item['section']} > {item['page']}")
            print(f"        Content: {item['content_length']} characters | Site: {item.get('site', 'Personal')}")
    
    if content_results['total_pages_found'] > 0:
        success_rate = (len(content_results['accessible']) / content_results['total_pages_tested']) * 100
        print(f"\n   📈 Success Rate: {success_rate:.1f}% of tested pages were readable")
        
        if content_results['total_pages_found'] > content_results['total_pages_tested']:
            print(f"   💡 Note: Only tested {content_results['total_pages_tested']} out of {content_results['total_pages_found']} total pages (5 random samples per notebook)")
    
    return content_results

def main():
    """Run comprehensive OneNote access tests"""
    print("🚀 Detailed OneNote Access Test")
    print("=" * 50)
    
    # Test authentication
    access_token = test_authentication()
    if not access_token:
        print("\n❌ Cannot proceed without authentication")
        return
    
    # Test basic OneNote access
    personal_notebooks = test_basic_onenote_access(access_token)
    
    # Test shared notebooks via teams (limited permissions)
    team_notebooks = test_shared_notebooks_via_groups(access_token)
    
    # Test SharePoint OneNote access
    site_notebooks = test_sharepoint_onenote_access(access_token)
    
    # Search for OneNote files via drive API
    drive_notebooks = test_onenote_via_drive_search(access_token)
    
    # Check recent files for OneNote
    recent_notebooks = test_recent_files_for_onenote(access_token)
    
    # Test alternative endpoints
    test_alternative_endpoints(access_token)
    
    # Test reading actual notebook content
    content_results = test_reading_notebook_content(access_token, personal_notebooks, site_notebooks)
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 SUMMARY:")
    print(f"   Personal notebooks: {len(personal_notebooks)}")
    print(f"   Team notebooks: {len(team_notebooks)}")
    print(f"   SharePoint notebooks: {len(site_notebooks)}")
    print(f"   Drive search results: {len(drive_notebooks)}")
    print(f"   Recent OneNote files: {len(recent_notebooks)}")
    
    # Add content reading results to summary
    if content_results:
        print(f"   Notebooks with readable content: {len(content_results['accessible'])}")
        print(f"   Restricted/rate-limited notebooks: {len(content_results['restricted'])}")
        print(f"   Failed content reads: {len(content_results['failed'])}")
    
    total_found = len(personal_notebooks) + len(team_notebooks) + len(site_notebooks) + len(drive_notebooks) + len(recent_notebooks)
    print(f"   Total items found: {total_found}")
    
    if total_found <= 1:
        print("\n⚠️  Limited notebooks found. Possible reasons:")
        print("   • Organization restricts OneNote API access")
        print("   • Shared notebooks require Group.Read.All permission")
        print("   • Notebooks might be accessed through specific Teams/SharePoint sites")
        print("   • Some notebooks might be in personal OneDrive with different sharing")
        print("\n💡 Try accessing OneNote through:")
        print("   • Teams app (check OneNote tabs in channels)")
        print("   • SharePoint sites directly")
        print("   • office.com/onenote")
    else:
        print(f"\n✅ Found multiple OneNote sources! Consider expanding access.")
        
    print(f"\n🔑 Current permissions working: User.Read, Notes.Read.All, Notes.ReadWrite.All, Sites.Read.All, Files.Read.All")
    print(f"🚫 Missing: Group.Read.All (requires admin consent)")
    
    return {
        'personal': personal_notebooks,
        'teams': team_notebooks, 
        'sharepoint': site_notebooks,
        'drive_search': drive_notebooks,
        'recent': recent_notebooks
    }

if __name__ == "__main__":
    main()
