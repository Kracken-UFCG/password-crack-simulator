#!/usr/bin/env python3
"""
Password Crack API Server
Receives requests from frontend, runs C++ binary, logs to CSV, returns JSON
"""

import subprocess
import csv
import json
import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs

# Configuration
PORT = int(os.environ.get('PORT', 8082))
RESULTS_CSV = "results.csv"
CPU_BINARY = "./password-crack-cpu"
GPU_BINARY = "./password-crack-gpu"

class CrackHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_POST(self):
        if self.path != '/crack':
            self.send_error(404)
            return

        # Parse form data
        content_length = int(self.headers['Content-Length'])
        body = self.rfile.read(content_length).decode('utf-8')
        params = parse_qs(body)

        password = params.get('password', [''])[0]
        strength = params.get('strength', [''])[0]
        use_gpu = params.get('gpu', ['false'])[0].lower() == 'true'

        if not password or not strength:
            self.send_error(400, "Missing password or strength")
            return

        # Choose binary
        binary = GPU_BINARY if use_gpu and os.path.exists(GPU_BINARY) else CPU_BINARY

        if not os.path.exists(binary):
            self.send_error(500, f"Binary not found: {binary}")
            return

        print(f"[server] Processing: password={password}, strength={strength}, binary={binary}")

        # Run C++ binary and capture output
        try:
            result = subprocess.run(
                [binary, password, strength],
                capture_output=True,
                text=True,
                timeout=300  # 5 min timeout
            )

            if result.returncode != 0:
                self.send_error(500, f"Binary failed: {result.stderr}")
                return

            # Parse CSV output (header + data row)
            lines = result.stdout.strip().split('\n')
            if len(lines) < 2:
                self.send_error(500, "Invalid binary output")
                return

            header = lines[0].split(',')
            data = lines[1].split(',')

            # Build result dict
            result_dict = dict(zip(header, data))
            result_dict['timestamp'] = datetime.now().isoformat()
            result_dict['binary'] = 'gpu' if use_gpu else 'cpu'

            # Append to CSV file
            self._append_to_csv(result_dict)

            # Return JSON
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(result_dict).encode('utf-8'))

            print(f"[server] Success: {result_dict['method']} in {result_dict['cracktime_s']}s")

        except subprocess.TimeoutExpired:
            self.send_error(504, "Request timeout (>5min)")
        except Exception as e:
            self.send_error(500, f"Error: {str(e)}")

    def _append_to_csv(self, result_dict):
        """Append result to CSV file, create with header if doesn't exist"""
        file_exists = os.path.exists(RESULTS_CSV)

        with open(RESULTS_CSV, 'a', newline='') as f:
            # Ensure consistent field order
            fieldnames = [
                'timestamp', 'password', 'strength', 'leaked',
                'dict_entries_checked', 'dict_time_s', 'cracktime_s',
                'attempts', 'latency_ns', 'method', 'binary'
            ]

            writer = csv.DictWriter(f, fieldnames=fieldnames)

            if not file_exists:
                writer.writeheader()

            writer.writerow(result_dict)

    def log_message(self, format, *args):
        """Suppress default logging, use custom"""
        pass

def main():
    # Check if binary exists
    if not os.path.exists(CPU_BINARY):
        print(f"ERROR: {CPU_BINARY} not found. Run 'make cpu' first.")
        return

    server = HTTPServer(('0.0.0.0', PORT), CrackHandler)
    print(f"")
    print(f"╔═══════════════════════════════════════════════════════════╗")
    print(f"║       Password Crack API Server                           ║")
    print(f"╚═══════════════════════════════════════════════════════════╝")
    print(f"")
    print(f"  Listening on:  http://0.0.0.0:{PORT}")
    print(f"  Results CSV:   {RESULTS_CSV}")
    print(f"  CPU binary:    {CPU_BINARY}")
    if os.path.exists(GPU_BINARY):
        print(f"  GPU binary:    {GPU_BINARY} ✓")
    else:
        print(f"  GPU binary:    not available (CPU only)")
    print(f"")
    print(f"  Route:  POST /crack")
    print(f"          password=<pwd>&strength=<str>&gpu=<true|false>")
    print(f"")
    print(f"  Press Ctrl+C to stop")
    print(f"")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[server] Shutting down...")
        server.shutdown()

if __name__ == '__main__':
    main()