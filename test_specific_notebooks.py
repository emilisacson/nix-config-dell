#!/usr/bin/env python3
"""
Test Access to Specific OneNote Notebooks
Extract notebook IDs from URLs and test API access
"""

import json
import requests
from msal import PublicClientApplication
import urllib.parse
import re

# CONFIGURE THESE VALUES
CLIENT_ID = "8a52ee61-c61a-4873-bfc6-489fa574e92c"
TENANT_ID = "d8fe6df3-c89e-4fa6-a2f8-cfcc31dffb1c"

def extract_notebook_info_from_urls():
    """Extract notebook IDs and site info from the provided URLs"""
    urls = [
        "https://composeit-my.sharepoint.com/:o:/r/personal/emil_isacson_compose_se/_layouts/15/Doc.aspx?sourcedoc=%7B2013FA0E-59F8-4E1C-B871-8D16FF4AA62D%7D&file=Emil%20%40%20Compose%20IT%20Nordic%20AB&action=edit&mobileredirect=true&wdorigin=Sharepoint",
        "https://composeit.sharepoint.com/:o:/r/sites/CustomerTeamCompose/_layouts/15/Doc.aspx?sourcedoc=%7B6CA49712-8615-4AFE-8381-EBA63D60BE9D%7D&file=Anteckningsbok%20f%C3%B6r%20CustomerTeamCompose&action=edit&mobileredirect=true&wdorigin=Sharepoint&DefaultItemOpen=1",
        "https://composeit.sharepoint.com/sites/SupplierInfoCompose/_layouts/15/Doc.aspx?sourcedoc={97ab6d2d-71e2-4c76-a7c7-2e9227915f53}&action=edit&wd=target%28IBM%28WAIOPs%5C%29.one%7Cfa023c60-68a1-4303-963a-0bfa3eab412f%2FIBM%20Partner%20World%7Ced07037e-3894-4826-867e-8655805b61da%2F%29&wdorigin=NavigationUrl",
        "https://composeit.sharepoint.com/sites/ComposeForum/_layouts/15/Doc.aspx?sourcedoc={30a75bc1-e2b2-4e8c-a317-8f5e95accd4b}&action=edit&wd=target%28Info%20och%20dokument.one%7C46261d12-6b42-43e3-b598-b6278f5bc4f9%2FStruktur%7C5cb45f1c-8a13-4ea0-b133-73b740709712%2F%29&wdorigin=NavigationUrl",
        "https://composeit.sharepoint.com/sites/Knowledge/_layouts/15/Doc.aspx?sourcedoc={7074c31a-dfae-477a-bbf0-3c6b8c54defd}&action=edit&wd=target%28Knowledge.one%7Cd6e41440-eb06-4609-9e6e-1bdb152777b9%2FInneh%C3%A5ll%7Cc936cea7-6b18-4769-a090-338a93fd0b0d%2F%29&wdorigin=NavigationUrl"
    ]
    
    notebooks = []
    
    for url in urls:
        parsed = urllib.parse.urlparse(url)
        query_params = urllib.parse.parse_qs(parsed.query)
        
        # Extract sourcedoc ID
        sourcedoc = None
        if 'sourcedoc' in query_params:
            sourcedoc_raw = query_params['sourcedoc'][0]
            # Remove URL encoding and brackets
            sourcedoc = sourcedoc_raw.replace('%7B', '').replace('%7D', '').replace('{', '').replace('}', '')
        
        # Extract site info
        if 'personal/' in url:
            site_type = 'personal'
            site_path = 'personal/emil_isacson_compose_se'
        elif '/sites/' in url:
            site_type = 'site'
            site_match = re.search(r'/sites/([^/_]+)', url)
            site_path = f"sites/{site_match.group(1)}" if site_match else "unknown"
        else:
            site_type = 'unknown'
            site_path = 'unknown'
        
        # Extract file name
        file_name = "Unknown"
        if 'file=' in url:
            file_param = [param for param in query_params.get('file', []) if param]
            if file_param:
                file_name = urllib.parse.unquote(file_param[0])
        
        notebooks.append({
            'url': url,
            'sourcedoc_id': sourcedoc,
            'site_type': site_type,
            'site_path': site_path,
            'file_name': file_name
        })
    
    return notebooks

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
            scopes=["User.Read", "Notes.Read.All", "Notes.ReadWrite.All", "Sites.Read.All", "Files.Read.All"],
            account=accounts[0]
        )
    else:
        result = None
    
    # If no cached token, get new one interactively
    if not result:
        print("🌐 Opening browser for authentication...")
        result = app.acquire_token_interactive(
            scopes=["User.Read", "Notes.Read.All", "Notes.ReadWrite.All", "Sites.Read.All", "Files.Read.All"]
        )
    
    if "access_token" in result:
        print("✅ Authentication successful!")
        return result["access_token"]
    else:
        print(f"❌ Authentication failed: {result.get('error_description', 'Unknown error')}")
        return None

def make_graph_request(access_token, endpoint):
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

def test_notebook_access_by_id(access_token, notebook_info):
    """Test access to a specific notebook by ID"""
    print(f"\n📓 Testing: {notebook_info['file_name']}")
    print(f"   📍 Location: {notebook_info['site_type']} - {notebook_info['site_path']}")
    print(f"   🆔 Source Doc ID: {notebook_info['sourcedoc_id']}")
    
    # For personal notebooks, use /me/onenote/notebooks/{id}
    if notebook_info['site_type'] == 'personal':
        # Try to find the notebook in user's personal notebooks first
        result, error = make_graph_request(access_token, '/me/onenote/notebooks')
        
        if result:
            notebooks = result.get('value', [])
            found_notebook = None
            
            for nb in notebooks:
                # Check if this notebook matches the sourcedoc ID
                nb_id = nb.get('id', '')
                if notebook_info['sourcedoc_id'].lower() in nb_id.lower():
                    found_notebook = nb
                    break
            
            if found_notebook:
                print(f"   ✅ Found personal notebook!")
                print(f"      📝 Name: {found_notebook.get('displayName', 'Unknown')}")
                print(f"      🆔 API ID: {found_notebook.get('id', 'Unknown')}")
                
                # Test getting sections
                nb_api_id = found_notebook.get('id')
                if nb_api_id:
                    sections_result, sections_error = make_graph_request(access_token, f'/me/onenote/notebooks/{nb_api_id}/sections')
                    if sections_result:
                        sections = sections_result.get('value', [])
                        print(f"      📂 Sections: {len(sections)}")
                        for section in sections[:3]:  # Show first 3 sections
                            print(f"         - {section.get('displayName', 'Unnamed')}")
                        if len(sections) > 3:
                            print(f"         ... and {len(sections) - 3} more")
                    else:
                        print(f"      ❌ Could not get sections: {sections_error}")
                
                return True
            else:
                print(f"   ❌ Notebook not found in personal notebooks")
                return False
        else:
            print(f"   ❌ Could not access personal notebooks: {error}")
            return False
    
    # For site notebooks, we need to find the site first and then the notebook
    elif notebook_info['site_type'] == 'site':
        site_name = notebook_info['site_path'].split('/')[-1]
        
        # First, get all sites to find the matching one
        sites_result, sites_error = make_graph_request(access_token, '/me/followedSites')
        
        if sites_result:
            sites = sites_result.get('value', [])
            found_site = None
            
            for site in sites:
                if site_name.lower() in site.get('displayName', '').lower() or site_name.lower() in site.get('name', '').lower():
                    found_site = site
                    break
            
            if found_site:
                site_id = found_site.get('id')
                print(f"   🌐 Found matching site: {found_site.get('displayName', 'Unknown')}")
                print(f"      🆔 Site ID: {site_id}")
                
                # Get notebooks for this site
                notebooks_result, notebooks_error = make_graph_request(access_token, f'/sites/{site_id}/onenote/notebooks')
                
                if notebooks_result:
                    notebooks = notebooks_result.get('value', [])
                    found_notebook = None
                    
                    # Try to match by name or ID
                    for nb in notebooks:
                        nb_name = nb.get('displayName', '')
                        nb_id = nb.get('id', '')
                        
                        if (notebook_info['file_name'].lower() in nb_name.lower() or 
                            notebook_info['sourcedoc_id'].lower() in nb_id.lower()):
                            found_notebook = nb
                            break
                    
                    if found_notebook:
                        print(f"   ✅ Found site notebook!")
                        print(f"      📝 Name: {found_notebook.get('displayName', 'Unknown')}")
                        print(f"      🆔 API ID: {found_notebook.get('id', 'Unknown')}")
                        
                        # Test getting sections
                        nb_api_id = found_notebook.get('id')
                        if nb_api_id:
                            sections_result, sections_error = make_graph_request(access_token, f'/sites/{site_id}/onenote/notebooks/{nb_api_id}/sections')
                            if sections_result:
                                sections = sections_result.get('value', [])
                                print(f"      📂 Sections: {len(sections)}")
                                for section in sections[:3]:  # Show first 3 sections
                                    print(f"         - {section.get('displayName', 'Unnamed')}")
                                if len(sections) > 3:
                                    print(f"         ... and {len(sections) - 3} more")
                            else:
                                print(f"      ❌ Could not get sections: {sections_error}")
                        
                        return True
                    else:
                        print(f"   ❌ Notebook not found in site")
                        print(f"      Available notebooks in {site_name}:")
                        for nb in notebooks[:5]:
                            print(f"         - {nb.get('displayName', 'Unnamed')}")
                        return False
                else:
                    print(f"   ❌ Could not get notebooks for site: {notebooks_error}")
                    return False
            else:
                print(f"   ❌ Site '{site_name}' not found in followed sites")
                print(f"   Available sites:")
                for site in sites[:5]:
                    print(f"      - {site.get('displayName', 'Unknown')}")
                return False
        else:
            print(f"   ❌ Could not get sites: {sites_error}")
            return False
    
    return False

def main():
    """Test access to specific OneNote notebooks"""
    print("🚀 Testing Access to Specific OneNote Notebooks")
    print("=" * 60)
    
    # Extract notebook info from URLs
    notebooks = extract_notebook_info_from_urls()
    
    print(f"📋 Found {len(notebooks)} notebooks to test:")
    for i, nb in enumerate(notebooks, 1):
        print(f"   {i}. {nb['file_name']} ({nb['site_type']})")
    
    # Test authentication
    access_token = test_authentication()
    if not access_token:
        print("\n❌ Cannot proceed without authentication")
        return
    
    # Test each notebook
    successful_notebooks = []
    failed_notebooks = []
    
    for notebook_info in notebooks:
        success = test_notebook_access_by_id(access_token, notebook_info)
        if success:
            successful_notebooks.append(notebook_info)
        else:
            failed_notebooks.append(notebook_info)
    
    # Summary
    print("\n" + "=" * 60)
    print("📊 SUMMARY:")
    print(f"   ✅ Accessible notebooks: {len(successful_notebooks)}")
    print(f"   ❌ Inaccessible notebooks: {len(failed_notebooks)}")
    
    if successful_notebooks:
        print("\n✅ Successfully accessed:")
        for nb in successful_notebooks:
            print(f"   📓 {nb['file_name']}")
    
    if failed_notebooks:
        print("\n❌ Could not access:")
        for nb in failed_notebooks:
            print(f"   📓 {nb['file_name']} ({nb['site_type']})")
            print(f"      This may require different permissions or site access")
    
    print(f"\n💡 To create export script for accessible notebooks, we can use the successful ones.")
    
    return {
        'successful': successful_notebooks,
        'failed': failed_notebooks
    }

if __name__ == "__main__":
    main()
