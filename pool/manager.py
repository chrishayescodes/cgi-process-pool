#!/usr/bin/env python3
import subprocess
import time
import requests
import threading
import signal
import sys
import os
import json
from collections import defaultdict
from datetime import datetime
from pathlib import Path

class CGIPool:
    def __init__(self, script_path, min_processes=2, max_processes=5):
        self.script_path = script_path
        self.min_processes = min_processes
        self.max_processes = max_processes
        self.processes = {}
        self.next_port = 8000
        self.lock = threading.Lock()
        self.request_count = defaultdict(int)
        
    def spawn_process(self):
        """Spawn a new CGI process on an available port"""
        with self.lock:
            if len(self.processes) >= self.max_processes:
                print(f"⚠️  Max processes ({self.max_processes}) reached for {self.script_path}")
                return None
                
            port = self.next_port
            self.next_port += 1
            
            try:
                if self.script_path.startswith('python3 '):
                    cmd = self.script_path.split(' ') + [str(port)]
                else:
                    cmd = [self.script_path, str(port)]
                process = subprocess.Popen(cmd, 
                                         stdout=subprocess.PIPE, 
                                         stderr=subprocess.PIPE)
                
                time.sleep(0.2)
                
                try:
                    response = requests.get(f"http://localhost:{port}?q=healthcheck", timeout=1)
                    if response.status_code == 200:
                        self.processes[port] = {
                            'process': process,
                            'port': port,
                            'healthy': True,
                            'created': time.time(),
                            'requests': 0
                        }
                        print(f"✓ Spawned {os.path.basename(self.script_path)} on port {port} (PID: {process.pid})")
                        return port
                except requests.exceptions.RequestException:
                    process.terminate()
                    print(f"✗ Failed to verify {self.script_path} on port {port}")
                    
            except Exception as e:
                print(f"✗ Failed to spawn {self.script_path}: {e}")
                
        return None
    
    def health_check(self):
        """Check health of all processes"""
        unhealthy = []
        
        with self.lock:
            for port, info in self.processes.items():
                if info['process'].poll() is not None:
                    info['healthy'] = False
                    unhealthy.append(port)
                else:
                    try:
                        response = requests.get(f"http://localhost:{port}?q=health", timeout=0.5)
                        info['healthy'] = response.status_code == 200
                        if info['healthy']:
                            info['requests'] = self.request_count[port]
                    except:
                        info['healthy'] = False
                        unhealthy.append(port)
            
            for port in unhealthy:
                print(f"✗ Process on port {port} unhealthy, removing")
                try:
                    self.processes[port]['process'].terminate()
                except:
                    pass
                del self.processes[port]
    
    def ensure_min_processes(self):
        """Ensure we have minimum number of healthy processes"""
        healthy_count = sum(1 for info in self.processes.values() if info['healthy'])
        
        spawned = 0
        while healthy_count < self.min_processes and spawned < self.min_processes:
            port = self.spawn_process()
            if port:
                healthy_count += 1
            spawned += 1
    
    def scale_up(self):
        """Scale up if needed based on load"""
        if len(self.processes) < self.max_processes:
            avg_requests = sum(info['requests'] for info in self.processes.values()) / max(len(self.processes), 1)
            if avg_requests > 10:
                self.spawn_process()
    
    def get_process_ports(self):
        """Get list of healthy process ports for nginx upstream"""
        with self.lock:
            return [info['port'] for info in self.processes.values() if info['healthy']]
    
    def terminate_all(self):
        """Terminate all processes in the pool"""
        with self.lock:
            for port, info in self.processes.items():
                try:
                    info['process'].terminate()
                    print(f"⏹  Terminated process on port {port}")
                except:
                    pass
            self.processes.clear()

class PoolManager:
    def __init__(self):
        self.pools = {}
        self.running = True
        
    def add_pool(self, name, executable, min_processes=2, max_processes=5):
        """Add a new CGI pool"""
        self.pools[name] = CGIPool(executable, min_processes, max_processes)
        
    def start(self):
        """Initialize all pools"""
        print("🚀 Starting CGI Pool Manager")
        print(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print("-" * 50)
        
        for name, pool in self.pools.items():
            print(f"Initializing {name} pool...")
            pool.ensure_min_processes()
        
        print("-" * 50)
        print("✅ All pools initialized")
        print("📊 Monitoring health every 5 seconds")
        print("Press Ctrl+C to stop")
        print("-" * 50)
        
        while self.running:
            time.sleep(5)
            for name, pool in self.pools.items():
                pool.health_check()
                pool.ensure_min_processes()
                pool.scale_up()
            
            self.update_nginx_config()
    
    def update_nginx_config(self):
        """Generate nginx upstream configuration"""
        config = "# Auto-generated upstream configuration\n"
        config += f"# Generated at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n"
        
        for name, pool in self.pools.items():
            ports = pool.get_process_ports()
            if ports:
                config += f"upstream {name}_pool {{\n"
                config += "    least_conn;\n"
                for port in ports:
                    config += f"    server 127.0.0.1:{port} max_fails=3 fail_timeout=10s;\n"
                config += "}\n\n"
        
        os.makedirs('/tmp', exist_ok=True)
        with open('/tmp/cgi_upstreams.conf', 'w') as f:
            f.write(config)
    
    def shutdown(self):
        """Gracefully shutdown all pools"""
        print("\n" + "=" * 50)
        print("🛑 Shutting down CGI Pool Manager...")
        self.running = False
        
        for name, pool in self.pools.items():
            print(f"Terminating {name} pool...")
            pool.terminate_all()
        
        print("✅ All pools terminated")
        print("=" * 50)

def load_manifest():
    """Load manifest.json - required for operation"""
    manifest_path = Path("discovery/manifest.json")
    if not manifest_path.exists():
        print(f"❌ {manifest_path} not found", file=sys.stderr)
        print("The manifest.json file is required for pool configuration.", file=sys.stderr)
        return None
    
    try:
        with open(manifest_path, 'r') as f:
            return json.load(f)
    except json.JSONDecodeError as e:
        print(f"❌ Error parsing {manifest_path}: {e}")
        return None

def configure_from_manifest(manager, manifest):
    """Configure pools from manifest.json"""
    samples = manifest.get('samples', {})
    configured = 0
    
    for name, sample in samples.items():
        language = sample.get('language')
        
        if language == 'c':
            exec_name = sample.get('executable', f'{name}.cgi')
            exec_path = f'./build/{exec_name}'
            
            if os.path.exists(exec_path):
                ports = sample.get('default_ports', [])
                if len(ports) >= 2:
                    min_proc, max_proc = 2, len(ports) + 1
                else:
                    min_proc, max_proc = 1, 3
                
                manager.add_pool(name, exec_path, min_processes=min_proc, max_processes=max_proc)
                print(f"✓ Configured {name} pool: {exec_path} ({min_proc}-{max_proc} processes)")
                configured += 1
            else:
                print(f"⚠️  {exec_path} not found, skipping {name}")
        
        elif language == 'python':
            exec_path = Path(sample.get('path'))
            
            if exec_path.exists():
                manager.add_pool(name, f'python3 {exec_path}', min_processes=1, max_processes=3)
                print(f"✓ Configured {name} pool: python3 {exec_path}")
                configured += 1
            else:
                print(f"⚠️  {exec_path} not found, skipping {name}")
    
    return configured

def signal_handler(signum, frame):
    """Handle shutdown signals"""
    if hasattr(signal_handler, 'manager'):
        signal_handler.manager.shutdown()
    sys.exit(0)

def main():
    manager = PoolManager()
    
    signal_handler.manager = manager
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    manifest = load_manifest()
    if manifest:
        configured = configure_from_manifest(manager, manifest)
        if configured > 0:
            print(f"🔍 Discovered and configured {configured} pools from manifest.json")
        else:
            print("❌ No valid applications found in manifest. Build applications first with 'make'.")
            sys.exit(1)
    else:
        print("📋 Using manual configuration...")
        if os.path.exists('./build/search.cgi'):
            manager.add_pool('search', './build/search.cgi', min_processes=2, max_processes=5)
        else:
            print("⚠️  build/search.cgi not found, skipping")
        
        if os.path.exists('./build/auth.cgi'):
            manager.add_pool('auth', './build/auth.cgi', min_processes=1, max_processes=3)
        else:
            print("⚠️  build/auth.cgi not found, skipping")
        
        if not manager.pools:
            print("❌ No CGI executables found. Please build them first.")
            sys.exit(1)
    
    try:
        manager.start()
    except KeyboardInterrupt:
        manager.shutdown()
    except Exception as e:
        print(f"❌ Error: {e}")
        manager.shutdown()
        sys.exit(1)

if __name__ == "__main__":
    main()