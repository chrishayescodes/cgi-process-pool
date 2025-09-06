#!/usr/bin/env python3
"""
Discovery System for CGI Process Pool
Parses manifest.json and provides information for build systems
"""

import json
import os
import sys
import argparse
from pathlib import Path

MANIFEST_FILE = Path("manifest.json")

def load_manifest():
    """Load the manifest file - required for operation"""
    if not MANIFEST_FILE.exists():
        print(f"Error: {MANIFEST_FILE} not found", file=sys.stderr)
        print("The manifest.json file is required for the discovery system to work.", file=sys.stderr)
        return None
    
    try:
        with open(MANIFEST_FILE, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"Error parsing {MANIFEST_FILE}: {e}", file=sys.stderr)
        return None

def get_c_samples(manifest):
    """Get all C language samples"""
    samples = []
    for name, sample in manifest.get('samples', {}).items():
        if sample.get('language') == 'c':
            samples.append({
                'name': name,
                'path': Path(sample['path']),
                'executable': sample.get('executable', f"{name}.cgi"),
                'ports': sample.get('default_ports', [])
            })
    return samples

def get_python_samples(manifest):
    """Get all Python language samples"""
    samples = []
    for name, sample in manifest.get('samples', {}).items():
        if sample.get('language') == 'python':
            samples.append({
                'name': name,
                'path': Path(sample['path']),
                'executable': sample.get('executable', f"{name}.py"),
                'ports': sample.get('default_ports', [])
            })
    return samples

def get_sample_by_name(manifest, name):
    """Get a specific sample by name"""
    return manifest.get('samples', {}).get(name)

def list_makefile_targets(manifest):
    """Generate Makefile target list for C samples"""
    c_samples = get_c_samples(manifest)
    targets = []
    for sample in c_samples:
        exec_name = sample['executable']
        if exec_name.endswith('.cgi'):
            # Place in build directory
            targets.append(f"build/{exec_name}")
    return ' '.join(targets)

def generate_makefile_rules(manifest):
    """Generate Makefile rules for building C samples"""
    c_samples = get_c_samples(manifest)
    rules = []
    
    for sample in c_samples:
        exec_name = sample['executable']
        source_path = sample['path']
        
        if exec_name.endswith('.cgi'):
            rule = f"""build/{exec_name}: {source_path} | build
\t$(CC) $(CFLAGS) -o $@ $<
\t@echo "✓ Built {exec_name} from {sample['name']} sample\""""
            rules.append(rule)
    
    return '\n\n'.join(rules)

def list_pool_configs(manifest):
    """Generate pool manager configuration entries"""
    configs = []
    
    # C samples
    for sample in get_c_samples(manifest):
        name = sample['name']
        exec_path = f"./build/{sample['executable']}"
        ports = sample['ports']
        
        if len(ports) >= 2:
            min_proc = 2
            max_proc = len(ports) + 1
        else:
            min_proc = 1
            max_proc = 3
            
        configs.append({
            'name': name,
            'executable': exec_path,
            'min_processes': min_proc,
            'max_processes': max_proc,
            'ports': ports
        })
    
    # Python samples
    for sample in get_python_samples(manifest):
        name = sample['name']
        exec_path = str(sample['path'])
        ports = sample['ports']
        
        configs.append({
            'name': name,
            'executable': f"python3 {exec_path}",
            'min_processes': 1,
            'max_processes': 3,
            'ports': ports
        })
    
    return configs

def main():
    parser = argparse.ArgumentParser(description='Sample Discovery System')
    parser.add_argument('command', choices=['targets', 'rules', 'list', 'info', 'pool-config'],
                        help='Command to execute')
    parser.add_argument('--name', help='Sample name for info command')
    parser.add_argument('--language', choices=['c', 'python', 'all'], default='all',
                        help='Filter by language')
    parser.add_argument('--format', choices=['text', 'json', 'makefile'], default='text',
                        help='Output format')
    
    args = parser.parse_args()
    
    manifest = load_manifest()
    if not manifest:
        return 1
    
    if args.command == 'targets':
        # Output Makefile targets for C samples
        print(list_makefile_targets(manifest))
    
    elif args.command == 'rules':
        # Output Makefile rules for building C samples
        print(generate_makefile_rules(manifest))
    
    elif args.command == 'list':
        # List all samples
        samples = manifest.get('samples', {})
        if args.format == 'json':
            print(json.dumps(list(samples.keys())))
        else:
            for name, sample in samples.items():
                if args.language == 'all' or sample.get('language') == args.language:
                    print(f"{name}: {sample.get('description', 'No description')}")
    
    elif args.command == 'info':
        # Show info about a specific sample
        if not args.name:
            print("Error: --name required for info command", file=sys.stderr)
            return 1
        
        sample = get_sample_by_name(manifest, args.name)
        if not sample:
            print(f"Error: Sample '{args.name}' not found", file=sys.stderr)
            return 1
        
        if args.format == 'json':
            print(json.dumps(sample, indent=2))
        else:
            print(f"Name: {sample.get('name', args.name)}")
            print(f"Description: {sample.get('description', 'N/A')}")
            print(f"Language: {sample.get('language', 'N/A')}")
            print(f"Path: {sample.get('path', 'N/A')}")
            print(f"Executable: {sample.get('executable', 'N/A')}")
            print(f"Default Ports: {sample.get('default_ports', [])}")
            print(f"API Endpoint: {sample.get('api_endpoint', 'N/A')}")
    
    elif args.command == 'pool-config':
        # Generate pool manager configuration
        configs = list_pool_configs(manifest)
        if args.format == 'json':
            print(json.dumps(configs, indent=2))
        else:
            for config in configs:
                print(f"# {config['name']}")
                print(f"manager.add_pool('{config['name']}', '{config['executable']}', "
                      f"min_processes={config['min_processes']}, "
                      f"max_processes={config['max_processes']})")
                print()
    
    return 0

if __name__ == '__main__':
    sys.exit(main())