#!/usr/bin/env python3
"""
Test script to find "Anteckningsbok för Compose Gemensam" notebook
"""

import json
import msal
import requests
from rich.console import Console
from rich.table import Table
from rich import print

console = Console()

# Configuration
CLIENT_ID = "8a52ee61-c61a-4873-bfc6-489fa574e92c"
SCOPES = [
    "https://graph.microsoft.com/User.Read",
    "https://graph.microsoft.com/Notes.Read.All",
    "https://graph.microsoft.com/Sites.Read.All",
    "https://graph.microsoft.com/Files.Read.All"
]

def get_access_token():
    """Get access token using device code flow"""
    app = msal.PublicClientApplication(
        CLIENT_ID,
        authority="https://login.microsoftonline.com/common"
    )
    
    # Check if we have a cached token
    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(SCOPES, account=accounts[0])
        if result:
            return result['access_token']
    
    # If no cached token, get a new one
    flow = app.initiate_device_flow(scopes=SCOPES)
    print(f"Please go to {flow['verification_uri']} and enter code: {flow['user_code']}")
    
    result = app.acquire_token_by_device_flow(flow)
    if "access_token" in result:
        return result["access_token"]
    else:
        print(f"Error: {result.get('error_description', result)}")
        return None

def search_notebooks_by_name(token, search_terms):
    """Search for notebooks containing specific terms"""
    headers = {"Authorization": f"Bearer {token}"}
    found_notebooks = []
    
    print("\n[bold cyan]Searching for notebooks with terms:[/bold cyan]", search_terms)
    
    # 1. Search personal notebooks
    print("\n[yellow]Checking personal notebooks...[/yellow]")
    try:
        response = requests.get(
            "https://graph.microsoft.com/v1.0/me/onenote/notebooks",
            headers=headers
        )
        
        if response.status_code == 200:
            notebooks = response.json().get('value', [])
            for notebook in notebooks:
                name = notebook.get('displayName', '')
                for term in search_terms:
                    if term.lower() in name.lower():
                        found_notebooks.append({
                            'name': name,
                            'id': notebook.get('id'),
                            'location': 'Personal',
                            'site': 'N/A'
                        })
                        print(f"  ✓ Found: {name}")
        else:
            print(f"  ✗ Error accessing personal notebooks: {response.status_code}")
    except Exception as e:
        print(f"  ✗ Exception accessing personal notebooks: {e}")
    
    # 2. Search SharePoint sites
    print("\n[yellow]Checking SharePoint sites...[/yellow]")
    try:
        # Get followed sites
        response = requests.get(
            "https://graph.microsoft.com/v1.0/me/followedSites",
            headers=headers
        )
        
        if response.status_code == 200:
            sites = response.json().get('value', [])
            print(f"  Found {len(sites)} followed sites")
            
            for site in sites:
                site_name = site.get('displayName', '')
                site_id = site.get('id', '')
                print(f"  Checking site: {site_name}")
                
                # Get notebooks for this site
                try:
                    notebooks_response = requests.get(
                        f"https://graph.microsoft.com/v1.0/sites/{site_id}/onenote/notebooks",
                        headers=headers
                    )
                    
                    if notebooks_response.status_code == 200:
                        notebooks = notebooks_response.json().get('value', [])
                        for notebook in notebooks:
                            name = notebook.get('displayName', '')
                            for term in search_terms:
                                if term.lower() in name.lower():
                                    found_notebooks.append({
                                        'name': name,
                                        'id': notebook.get('id'),
                                        'location': 'SharePoint',
                                        'site': site_name
                                    })
                                    print(f"    ✓ Found: {name}")
                    else:
                        print(f"    ✗ Error accessing notebooks for {site_name}: {notebooks_response.status_code}")
                except Exception as e:
                    print(f"    ✗ Exception accessing notebooks for {site_name}: {e}")
        else:
            print(f"  ✗ Error accessing followed sites: {response.status_code}")
    except Exception as e:
        print(f"  ✗ Exception accessing followed sites: {e}")
    
    return found_notebooks

def list_all_notebook_names(token):
    """List all accessible notebook names for reference"""
    headers = {"Authorization": f"Bearer {token}"}
    all_notebooks = []
    
    print("\n[bold cyan]Listing ALL accessible notebooks for reference:[/bold cyan]")
    
    # Personal notebooks
    try:
        response = requests.get(
            "https://graph.microsoft.com/v1.0/me/onenote/notebooks",
            headers=headers
        )
        
        if response.status_code == 200:
            notebooks = response.json().get('value', [])
            for notebook in notebooks:
                all_notebooks.append({
                    'name': notebook.get('displayName', ''),
                    'location': 'Personal'
                })
    except Exception as e:
        print(f"Error accessing personal notebooks: {e}")
    
    # SharePoint notebooks
    try:
        response = requests.get(
            "https://graph.microsoft.com/v1.0/me/followedSites",
            headers=headers
        )
        
        if response.status_code == 200:
            sites = response.json().get('value', [])
            for site in sites:
                site_name = site.get('displayName', '')
                site_id = site.get('id', '')
                
                try:
                    notebooks_response = requests.get(
                        f"https://graph.microsoft.com/v1.0/sites/{site_id}/onenote/notebooks",
                        headers=headers
                    )
                    
                    if notebooks_response.status_code == 200:
                        notebooks = notebooks_response.json().get('value', [])
                        for notebook in notebooks:
                            all_notebooks.append({
                                'name': notebook.get('displayName', ''),
                                'location': f'SharePoint ({site_name})'
                            })
                except Exception:
                    pass
    except Exception as e:
        print(f"Error accessing SharePoint sites: {e}")
    
    # Display all notebooks in a table
    table = Table(title="All Accessible Notebooks")
    table.add_column("Notebook Name", style="cyan")
    table.add_column("Location", style="yellow")
    
    for notebook in all_notebooks:
        table.add_row(notebook['name'], notebook['location'])
    
    console.print(table)
    
    return all_notebooks

def main():
    print("[bold green]Testing access to 'Anteckningsbok för Compose Gemensam' notebook[/bold green]")
    
    # Get access token
    token = get_access_token()
    if not token:
        print("[red]Failed to get access token[/red]")
        return
    
    print("[green]✓ Successfully authenticated[/green]")
    
    # Search terms to look for
    search_terms = [
        "Compose Gemensam",
        "ComposeForum", 
        "Gemensam",
        "Forum"
    ]
    
    # Search for specific notebooks
    found_notebooks = search_notebooks_by_name(token, search_terms)
    
    # Display results
    if found_notebooks:
        print(f"\n[bold green]Found {len(found_notebooks)} matching notebooks:[/bold green]")
        
        table = Table(title="Matching Notebooks")
        table.add_column("Name", style="cyan")
        table.add_column("Location", style="yellow")
        table.add_column("Site", style="magenta")
        table.add_column("ID", style="dim")
        
        for notebook in found_notebooks:
            table.add_row(
                notebook['name'],
                notebook['location'], 
                notebook['site'],
                notebook['id'][:20] + "..." if len(notebook['id']) > 20 else notebook['id']
            )
        
        console.print(table)
        
        # Test access to found notebooks
        print("\n[bold cyan]Testing access to found notebooks:[/bold cyan]")
        headers = {"Authorization": f"Bearer {token}"}
        
        for notebook in found_notebooks:
            print(f"\n[yellow]Testing: {notebook['name']}[/yellow]")
            try:
                response = requests.get(
                    f"https://graph.microsoft.com/v1.0/me/onenote/notebooks/{notebook['id']}/sections",
                    headers=headers
                )
                
                if response.status_code == 200:
                    sections = response.json().get('value', [])
                    print(f"  ✓ Accessible - {len(sections)} sections found")
                    
                    # Show first few section names
                    for i, section in enumerate(sections[:3]):
                        print(f"    - {section.get('displayName', 'Unnamed')}")
                    if len(sections) > 3:
                        print(f"    ... and {len(sections) - 3} more sections")
                else:
                    print(f"  ✗ Access denied: {response.status_code}")
            except Exception as e:
                print(f"  ✗ Exception: {e}")
    else:
        print("\n[red]No notebooks found matching the search terms[/red]")
        
        # Show all notebooks for reference
        print("\n[yellow]Here are all accessible notebooks for reference:[/yellow]")
        list_all_notebook_names(token)

if __name__ == "__main__":
    main()
