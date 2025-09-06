#!/usr/bin/env python3
"""
Generate YARP appsettings.json from manifest.json
This script reads the service manifest and generates the appropriate YARP proxy configuration.
"""

import json
import sys
import os
from pathlib import Path

def load_manifest(manifest_path):
    """Load and parse the manifest.json file"""
    try:
        with open(manifest_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"Error: Manifest file not found at {manifest_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in manifest file: {e}")
        sys.exit(1)

def create_route_config(service_key, service_info):
    """Create a YARP route configuration for a service"""
    api_endpoint = service_info.get('api_endpoint', '')
    
    if not api_endpoint:
        print(f"Warning: Service {service_key} has no API endpoint, skipping")
        return None
    
    route_id = f"{service_key}-route"
    cluster_id = f"{service_key}-cluster"
    
    # Handle different endpoint patterns
    if api_endpoint.startswith('/api/'):
        # Traditional API endpoint pattern
        path_pattern = f"{api_endpoint}/{{**catch-all}}"
        transforms = [{"PathRemovePrefix": api_endpoint}]
    elif api_endpoint == '/':
        # Root endpoint pattern - use service name as prefix to avoid conflicts
        path_pattern = f"/{service_key}/{{**catch-all}}"
        transforms = [{"PathRemovePrefix": f"/{service_key}"}]
    else:
        # Custom endpoint pattern
        path_pattern = f"{api_endpoint}/{{**catch-all}}"
        transforms = [{"PathRemovePrefix": api_endpoint}]
    
    route_config = {
        "ClusterId": cluster_id,
        "Match": {
            "Path": path_pattern
        },
        "Transforms": transforms,
        "Metadata": {
            "Service": service_key,
            "ServiceName": service_info.get('name', service_key),
            "Language": service_info.get('language', 'unknown')
        }
    }
    
    return route_id, route_config

def create_cluster_config(service_key, service_info):
    """Create a YARP cluster configuration for a service"""
    default_ports = service_info.get('default_ports', [])
    
    if not default_ports:
        print(f"Warning: Service {service_key} has no default ports, skipping")
        return None
    
    cluster_id = f"{service_key}-cluster"
    
    # Create destinations for each port
    destinations = {}
    for i, port in enumerate(default_ports):
        if len(default_ports) == 1:
            dest_id = f"{service_key}-1"
        else:
            dest_id = f"{service_key}-{i + 1}"
        
        destinations[dest_id] = {
            "Address": f"http://127.0.0.1:{port}/"
        }
    
    cluster_config = {
        "LoadBalancingPolicy": "RoundRobin",
        "Destinations": destinations
    }
    
    # Add health check if available
    health_check = service_info.get('health_check')
    if health_check:
        cluster_config["HealthCheck"] = {
            "Active": {
                "Enabled": True,
                "Interval": "00:00:10",
                "Timeout": "00:00:05",
                "Policy": "ConsecutiveFailures",
                "Path": health_check
            }
        }
    
    return cluster_id, cluster_config

def create_admin_routes():
    """Create the admin routes that are always needed"""
    return {
        "admin-route": {
            "ClusterId": "admin-cluster",
            "Match": {
                "Path": "/admin/{**catch-all}"
            },
            "Transforms": [
                {"PathRemovePrefix": "/admin"}
            ]
        },
        "admin-api-route": {
            "ClusterId": "admin-cluster",
            "Match": {
                "Path": "/admin-api/{**catch-all}"
            },
            "Transforms": [
                {"PathRemovePrefix": "/admin-api"},
                {"PathPrefix": "/api"}
            ]
        },
        "root-route": {
            "ClusterId": "admin-cluster",
            "Match": {
                "Path": "/"
            }
        }
    }

def create_admin_clusters():
    """Create the admin clusters that are always needed"""
    return {
        "admin-cluster": {
            "Destinations": {
                "admin-1": {
                    "Address": "http://127.0.0.1:5000/"
                }
            }
        }
    }

def generate_yarp_config(manifest_path, output_path):
    """Generate the complete YARP configuration"""
    print(f"Loading manifest from: {manifest_path}")
    manifest = load_manifest(manifest_path)
    
    # Load base configuration template
    base_config_path = os.path.join(os.path.dirname(output_path), "appsettings.base.json")
    if os.path.exists(base_config_path):
        print(f"Loading base configuration from: {base_config_path}")
        with open(base_config_path, 'r') as f:
            config = json.load(f)
    else:
        print("⚠️  Base configuration not found, using defaults")
        config = {
            "Logging": {
                "LogLevel": {
                    "Default": "Information",
                    "Microsoft.AspNetCore": "Warning",
                    "Yarp": "Information"
                }
            },
            "AllowedHosts": "*",
            "ReverseProxy": {
                "Routes": {},
                "Clusters": {}
            }
        }
    
    # Add admin routes and clusters
    config["ReverseProxy"]["Routes"].update(create_admin_routes())
    config["ReverseProxy"]["Clusters"].update(create_admin_clusters())
    
    # Process services from manifest
    services_processed = 0
    samples = manifest.get('samples', {})
    
    for service_key, service_info in samples.items():
        print(f"Processing service: {service_key}")
        
        # Create route configuration
        route_result = create_route_config(service_key, service_info)
        if route_result:
            route_id, route_config = route_result
            config["ReverseProxy"]["Routes"][route_id] = route_config
        
        # Create cluster configuration
        cluster_result = create_cluster_config(service_key, service_info)
        if cluster_result:
            cluster_id, cluster_config = cluster_result
            config["ReverseProxy"]["Clusters"][cluster_id] = cluster_config
            services_processed += 1
    
    # Write the configuration
    print(f"Writing configuration to: {output_path}")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    
    with open(output_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"✅ Generated YARP configuration with {services_processed} services")
    print(f"   Routes: {len(config['ReverseProxy']['Routes'])}")
    print(f"   Clusters: {len(config['ReverseProxy']['Clusters'])}")
    
    # Show discovered services
    print("\nDiscovered services:")
    for service_key, service_info in samples.items():
        api_endpoint = service_info.get('api_endpoint', 'N/A')
        ports = service_info.get('default_ports', [])
        
        if api_endpoint == '/':
            proxy_path = f"/{service_key}"
        else:
            proxy_path = api_endpoint
            
        print(f"  • {service_key}: {proxy_path} -> ports {ports}")

def main():
    """Main entry point"""
    if len(sys.argv) != 3:
        print("Usage: python3 generate-yarp-config.py <manifest.json> <output_appsettings.json>")
        sys.exit(1)
    
    manifest_path = sys.argv[1]
    output_path = sys.argv[2]
    
    generate_yarp_config(manifest_path, output_path)

if __name__ == "__main__":
    main()