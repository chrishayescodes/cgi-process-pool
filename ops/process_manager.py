#!/usr/bin/env python3
"""
CGI Process Pool - Hardened Process Lifecycle Manager

Provides robust startup, shutdown, and monitoring capabilities for the entire
CGI Process Pool system including pool manager, proxy server, and all services.
"""

import subprocess
import time
import json
import signal
import sys
import os
# import psutil  # Optional dependency
import threading
import atexit
from pathlib import Path
from datetime import datetime
from collections import defaultdict

class ProcessManager:
    def __init__(self, config_file="ops/process_config.json"):
        self.config_file = Path(config_file)
        self.running_processes = {}
        self.process_registry = {}
        self.lock = threading.Lock()
        self.shutdown_requested = False
        
        # Load configuration
        self.config = self.load_config()
        
        # Register cleanup on exit
        atexit.register(self.shutdown_all)
        
        # Handle signals
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def load_config(self):
        """Load process configuration from JSON file"""
        if not self.config_file.exists():
            return self.create_default_config()
        
        try:
            with open(self.config_file, 'r') as f:
                return json.load(f)
        except Exception as e:
            print(f"❌ Error loading config {self.config_file}: {e}")
            return self.create_default_config()
    
    def create_default_config(self):
        """Create default configuration"""
        return {
            "processes": {
                "pool_manager": {
                    "command": ["python3", "pool/manager.py"],
                    "cwd": ".",
                    "env": {},
                    "restart_policy": "always",
                    "startup_delay": 0,
                    "health_check": {
                        "type": "port",
                        "target": "8000",
                        "timeout": 5
                    }
                },
                "yarp_proxy": {
                    "command": ["dotnet", "run", "--urls=http://0.0.0.0:8080"],
                    "cwd": "proxy/CGIProxy",
                    "env": {},
                    "restart_policy": "always", 
                    "startup_delay": 2,
                    "depends_on": ["pool_manager"],
                    "health_check": {
                        "type": "http",
                        "url": "http://localhost:8080/admin",
                        "timeout": 5
                    }
                }
            },
            "global_settings": {
                "startup_timeout": 30,
                "shutdown_timeout": 10,
                "health_check_interval": 30,
                "log_directory": "logs"
            }
        }
    
    def save_config(self):
        """Save current configuration to file"""
        os.makedirs(self.config_file.parent, exist_ok=True)
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully"""
        print(f"\n🛑 Received signal {signum}, initiating graceful shutdown...")
        self.shutdown_requested = True
        self.shutdown_all()
        sys.exit(0)
    
    def start_process(self, name, config):
        """Start a single process with monitoring"""
        with self.lock:
            if name in self.running_processes:
                print(f"⚠️  Process {name} already running")
                return False
        
        print(f"🚀 Starting {name}...")
        
        try:
            # Prepare environment
            env = os.environ.copy()
            env.update(config.get('env', {}))
            
            # Start process
            process = subprocess.Popen(
                config['command'],
                cwd=config.get('cwd', '.'),
                env=env,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                preexec_fn=os.setsid  # Create new process group
            )
            
            # Wait for startup delay
            startup_delay = config.get('startup_delay', 0)
            if startup_delay > 0:
                time.sleep(startup_delay)
            
            # Register process
            with self.lock:
                self.running_processes[name] = {
                    'process': process,
                    'config': config,
                    'started_at': datetime.now(),
                    'restart_count': 0
                }
            
            # Perform health check
            if self.health_check(name):
                print(f"✅ {name} started successfully (PID: {process.pid})")
                return True
            else:
                print(f"❌ {name} health check failed")
                self.stop_process(name)
                return False
                
        except Exception as e:
            print(f"❌ Failed to start {name}: {e}")
            return False
    
    def stop_process(self, name, timeout=None):
        """Stop a single process gracefully"""
        if timeout is None:
            timeout = self.config['global_settings']['shutdown_timeout']
        
        with self.lock:
            if name not in self.running_processes:
                print(f"⚠️  Process {name} not running")
                return True
            
            process_info = self.running_processes[name]
            process = process_info['process']
        
        print(f"⏹  Stopping {name} (PID: {process.pid})...")
        
        try:
            # Try graceful shutdown first (SIGTERM to process group)
            os.killpg(os.getpgid(process.pid), signal.SIGTERM)
            
            # Wait for graceful shutdown
            try:
                process.wait(timeout=timeout)
                print(f"✅ {name} stopped gracefully")
            except subprocess.TimeoutExpired:
                print(f"⚠️  {name} didn't stop gracefully, forcing...")
                # Force kill (SIGKILL to process group)
                os.killpg(os.getpgid(process.pid), signal.SIGKILL)
                process.wait()
                print(f"✅ {name} force stopped")
                
        except ProcessLookupError:
            print(f"✅ {name} already stopped")
        except Exception as e:
            print(f"❌ Error stopping {name}: {e}")
        
        # Remove from registry
        with self.lock:
            if name in self.running_processes:
                del self.running_processes[name]
        
        return True
    
    def health_check(self, name):
        """Perform health check on a process"""
        if name not in self.running_processes:
            return False
        
        config = self.running_processes[name]['config']
        health_config = config.get('health_check')
        
        if not health_config:
            return True  # No health check defined
        
        check_type = health_config.get('type')
        timeout = health_config.get('timeout', 5)
        
        try:
            if check_type == 'port':
                import socket
                port = int(health_config['target'])
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(timeout)
                result = sock.connect_ex(('localhost', port)) == 0
                sock.close()
                return result
                
            elif check_type == 'http':
                import requests
                url = health_config['url']
                response = requests.get(url, timeout=timeout)
                return response.status_code == 200
                
            elif check_type == 'command':
                cmd = health_config['command']
                result = subprocess.run(cmd, shell=True, capture_output=True, timeout=timeout)
                return result.returncode == 0
                
        except Exception as e:
            print(f"⚠️  Health check failed for {name}: {e}")
            return False
        
        return True
    
    def start_all(self):
        """Start all processes in dependency order"""
        print("🚀 Starting CGI Process Pool System")
        print("=" * 50)
        
        # Create logs directory
        log_dir = self.config['global_settings']['log_directory']
        os.makedirs(log_dir, exist_ok=True)
        
        # Build dependency graph
        processes = self.config['processes']
        dependencies = {}
        
        for name, config in processes.items():
            dependencies[name] = config.get('depends_on', [])
        
        # Start processes in dependency order
        started = set()
        while len(started) < len(processes):
            progress_made = False
            
            for name, deps in dependencies.items():
                if name in started:
                    continue
                
                # Check if all dependencies are started
                if all(dep in started for dep in deps):
                    if self.start_process(name, processes[name]):
                        started.add(name)
                        progress_made = True
                    else:
                        print(f"❌ Failed to start {name}, aborting startup")
                        self.shutdown_all()
                        return False
            
            if not progress_made:
                print("❌ Circular dependency detected or startup failure")
                self.shutdown_all()
                return False
        
        print("=" * 50)
        print("✅ All processes started successfully")
        return True
    
    def shutdown_all(self):
        """Shutdown all processes in reverse dependency order"""
        if self.shutdown_requested:
            return  # Already shutting down
        
        self.shutdown_requested = True
        
        print("\n🛑 Shutting down CGI Process Pool System")
        print("=" * 50)
        
        # Clean up any orphaned processes first
        self.cleanup_orphaned_processes()
        
        # Get shutdown order (reverse of startup order)
        with self.lock:
            names = list(self.running_processes.keys())
        
        # Stop all processes
        for name in reversed(names):
            self.stop_process(name)
        
        print("=" * 50)
        print("✅ All processes stopped")
    
    def cleanup_orphaned_processes(self):
        """Clean up orphaned CGI processes from previous runs"""
        print("🧹 Cleaning up orphaned processes...")
        
        orphaned_count = 0
        
        try:
            # Use subprocess to find processes (fallback when psutil not available)
            patterns = [
                r'\.cgi',
                r'sample_python_cgi\.py',
                r'sample_csharp_cgi\.csx', 
                r'dotnet-script.*\.csx',
                r'pool/manager\.py',
                r'dotnet run.*8080'
            ]
            
            for pattern in patterns:
                try:
                    # Find processes matching pattern
                    result = subprocess.run(['pgrep', '-f', pattern], 
                                          capture_output=True, text=True)
                    
                    if result.returncode == 0 and result.stdout.strip():
                        pids = result.stdout.strip().split('\n')
                        
                        for pid_str in pids:
                            if not pid_str:
                                continue
                                
                            pid = int(pid_str)
                            
                            # Skip if it's one of our managed processes
                            is_managed = False
                            for name, process_info in self.running_processes.items():
                                if process_info['process'].pid == pid:
                                    is_managed = True
                                    break
                            
                            if not is_managed:
                                try:
                                    # Get process name for logging
                                    name_result = subprocess.run(['ps', '-p', str(pid), '-o', 'comm='],
                                                               capture_output=True, text=True)
                                    proc_name = name_result.stdout.strip() if name_result.returncode == 0 else f"PID_{pid}"
                                    
                                    print(f"🗑  Terminating orphaned process: {proc_name} (PID: {pid})")
                                    
                                    # Send SIGTERM first
                                    os.kill(pid, signal.SIGTERM)
                                    time.sleep(1)
                                    
                                    # Check if still running, force kill if needed
                                    try:
                                        os.kill(pid, 0)  # Check if process exists
                                        print(f"⚠️  Force killing stubborn process {pid}")
                                        os.kill(pid, signal.SIGKILL)
                                    except ProcessLookupError:
                                        pass  # Process already died
                                    
                                    orphaned_count += 1
                                    
                                except (ProcessLookupError, OSError):
                                    pass  # Process already dead or no permission
                                
                except (subprocess.SubprocessError, ValueError):
                    continue  # Skip this pattern if command fails
        
        except Exception as e:
            print(f"⚠️  Error during cleanup: {e}")
        
        if orphaned_count > 0:
            print(f"✅ Cleaned up {orphaned_count} orphaned processes")
        else:
            print("✅ No orphaned processes found")
    
    def status(self):
        """Show status of all processes"""
        print("📊 CGI Process Pool Status")
        print("=" * 50)
        
        with self.lock:
            if not self.running_processes:
                print("No processes running")
                return
            
            for name, process_info in self.running_processes.items():
                process = process_info['process']
                started_at = process_info['started_at']
                uptime = datetime.now() - started_at
                
                # Check if process is still alive
                if process.poll() is None:
                    health = "🟢 Healthy" if self.health_check(name) else "🟡 Unhealthy"
                    print(f"{name:15} | PID: {process.pid:6} | {health} | Uptime: {uptime}")
                else:
                    print(f"{name:15} | PID: {process.pid:6} | 🔴 Dead    | Uptime: {uptime}")
    
    def restart_process(self, name):
        """Restart a specific process"""
        print(f"🔄 Restarting {name}...")
        
        with self.lock:
            if name not in self.running_processes:
                print(f"❌ Process {name} not running")
                return False
            
            config = self.running_processes[name]['config']
        
        self.stop_process(name)
        return self.start_process(name, config)
    
    def monitor(self, interval=30):
        """Monitor processes and restart if needed"""
        print(f"👁  Starting process monitor (interval: {interval}s)")
        
        while not self.shutdown_requested:
            time.sleep(interval)
            
            if self.shutdown_requested:
                break
            
            with self.lock:
                processes_to_restart = []
                
                for name, process_info in list(self.running_processes.items()):
                    process = process_info['process']
                    config = process_info['config']
                    restart_policy = config.get('restart_policy', 'no')
                    
                    # Check if process died
                    if process.poll() is not None:
                        print(f"🔴 Process {name} died")
                        if restart_policy in ['always', 'on-failure']:
                            processes_to_restart.append(name)
                        else:
                            del self.running_processes[name]
                    
                    # Check health
                    elif not self.health_check(name):
                        print(f"🟡 Process {name} health check failed")
                        if restart_policy == 'always':
                            processes_to_restart.append(name)
            
            # Restart failed processes
            for name in processes_to_restart:
                self.restart_process(name)

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='CGI Process Pool - Process Manager')
    parser.add_argument('command', choices=['start', 'stop', 'restart', 'status', 'monitor', 'cleanup'],
                        help='Command to execute')
    parser.add_argument('--process', help='Specific process name (for restart command)')
    parser.add_argument('--config', default='ops/process_config.json', help='Configuration file')
    parser.add_argument('--monitor-interval', type=int, default=30, help='Monitor interval in seconds')
    
    args = parser.parse_args()
    
    manager = ProcessManager(args.config)
    
    if args.command == 'start':
        if manager.start_all():
            manager.monitor(args.monitor_interval)
    elif args.command == 'stop':
        manager.shutdown_all()
    elif args.command == 'restart':
        if args.process:
            manager.restart_process(args.process)
        else:
            manager.shutdown_all()
            time.sleep(2)
            manager.start_all()
    elif args.command == 'status':
        manager.status()
    elif args.command == 'monitor':
        manager.monitor(args.monitor_interval)
    elif args.command == 'cleanup':
        manager.cleanup_orphaned_processes()

if __name__ == '__main__':
    main()