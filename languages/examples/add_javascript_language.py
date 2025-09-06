#!/usr/bin/env python3
"""
Example: Adding JavaScript/Node.js support to the modular language system
"""

from manager import LanguageManager

def add_javascript_support():
    """Add JavaScript/Node.js language support"""
    
    manager = LanguageManager()
    
    # Define JavaScript language configuration
    javascript_config = {
        "name": "JavaScript (Node.js)",
        "description": "Node.js JavaScript services with npm ecosystem and async capabilities",
        "file_extension": ".js",
        "executable_extension": ".js", 
        "build_required": False,
        "runtime": {
            "command": "node ./{executable}",
            "health_check": "/?health=true",
            "requirements": ["Node.js 18+ and npm"]
        },
        "template": {
            "shebang": "#!/usr/bin/env node",
            "imports": [
                "const http = require('http');",
                "const url = require('url');", 
                "const querystring = require('querystring');"
            ],
            "port_parsing": "const port = parseInt(process.argv[2]);",
            "server_setup": "http.createServer() with request/response handling",
            "response_format": "JSON with native JSON.stringify"
        },
        "monitoring": {
            "process_pattern": "node.*\\.js",
            "name_extraction": "cmdLine.Contains(\"{service_name}.js\") ? \"{service_name}\" :"
        }
    }
    
    # Add the language
    manager.add_language('javascript', javascript_config)
    print("✅ Added JavaScript/Node.js language support")
    
    # Generate automation script
    script_content = manager.generate_automation_script('javascript')
    with open('add_javascript_cgi_app.sh', 'w') as f:
        f.write(script_content)
    
    import os
    os.chmod('add_javascript_cgi_app.sh', 0o755)
    print("✅ Generated add_javascript_cgi_app.sh")

def add_rust_support():
    """Add Rust language support"""
    
    manager = LanguageManager()
    
    # Define Rust language configuration
    rust_config = {
        "name": "Rust",
        "description": "High-performance Rust services with memory safety and speed",
        "file_extension": ".rs",
        "executable_extension": "",  # Compiled binary 
        "build_required": True,
        "runtime": {
            "command": "./{executable}",
            "build_command": "rustc --edition 2021 -O -o {executable} {source_file}",
            "health_check": "/?health=check",
            "requirements": ["Rust compiler (rustc)"]
        },
        "template": {
            "imports": [
                "use std::io::prelude::*;",
                "use std::net::{TcpListener, TcpStream};",
                "use std::thread;",
                "use std::env;"
            ],
            "main_function": "fn main()",
            "port_parsing": "let port: u16 = env::args().nth(1).unwrap().parse().unwrap();",
            "server_setup": "TcpListener::bind() with thread spawning",
            "response_format": "HTTP response with JSON string"
        },
        "monitoring": {
            "process_pattern": "[^/]*$",  # Binary name pattern
            "name_extraction": "cmdLine.Contains(\"{service_name}\") ? \"{service_name}\" :"
        }
    }
    
    # Add the language
    manager.add_language('rust', rust_config)
    print("✅ Added Rust language support")
    
    # Generate automation script
    script_content = manager.generate_automation_script('rust')
    with open('add_rust_cgi_app.sh', 'w') as f:
        f.write(script_content)
    
    import os
    os.chmod('add_rust_cgi_app.sh', 0o755)
    print("✅ Generated add_rust_cgi_app.sh")

if __name__ == '__main__':
    print("🚀 Demonstrating Modular Language System")
    print("=========================================")
    
    # Add JavaScript support
    print("\n📜 Adding JavaScript/Node.js...")
    add_javascript_support()
    
    # Add Rust support  
    print("\n🦀 Adding Rust...")
    add_rust_support()
    
    print("\n🎉 New languages added! Check:")
    print("   ./languages/manager.py list")
    print("   ./languages/add_language_service.sh javascript my_api 8020 2")
    print("   ./languages/add_language_service.sh rust fast_service 8022 3")