#!/bin/bash
set -e

cd "$(dirname "$0")"

python3 - <<'PY'
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from urllib.parse import quote
from functools import partial
import os
import socket
import subprocess
import shutil

html_name = "index.html"

with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
    sock.bind(("127.0.0.1", 0))
    port = sock.getsockname()[1]

class Handler(SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def handle(self):
        try:
            super().handle()
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *args):
        pass

    def send_head(self):
        self.range = None
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            return super().send_head()
        try:
            f = open(path, "rb")
        except OSError:
            self.send_error(404, "File not found")
            return None
        size = os.fstat(f.fileno()).st_size
        ctype = self.guess_type(path)
        range_header = self.headers.get("Range")
        if range_header and range_header.startswith("bytes="):
            start_text, _, end_text = range_header[6:].partition("-")
            try:
                start = int(start_text) if start_text else 0
                end = int(end_text) if end_text else size - 1
                end = min(end, size - 1)
                if start > end:
                    raise ValueError
                self.range = (start, end)
                self.send_response(206)
                self.send_header("Content-type", ctype)
                self.send_header("Accept-Ranges", "bytes")
                self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
                self.send_header("Content-Length", str(end - start + 1))
                self.end_headers()
                f.seek(start)
                return f
            except ValueError:
                self.send_error(416, "Requested Range Not Satisfiable")
                f.close()
                return None
        self.send_response(200)
        self.send_header("Content-type", ctype)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(size))
        self.end_headers()
        return f

    def copyfile(self, source, outputfile):
        try:
            if self.range:
                remaining = self.range[1] - self.range[0] + 1
                while remaining > 0:
                    chunk = source.read(min(64 * 1024, remaining))
                    if not chunk:
                        break
                    outputfile.write(chunk)
                    remaining -= len(chunk)
            else:
                shutil.copyfileobj(source, outputfile)
        except (BrokenPipeError, ConnectionResetError):
            pass

url = f"http://127.0.0.1:{port}/{quote(html_name)}"
print("本地预览已启动：", flush=True)
print(url, flush=True)
print(flush=True)
print("请不要关闭这个窗口；关闭窗口后，本地预览也会停止。", flush=True)
subprocess.Popen(["open", url])

server = ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=os.getcwd()))
server.serve_forever()
PY
