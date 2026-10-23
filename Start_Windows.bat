@echo off
setlocal EnableExtensions
chcp 65001 >nul
cd /d "%~dp0"

where py >nul 2>nul
if %errorlevel%==0 (
  set "PYTHON_CMD=py -3"
) else (
  where python >nul 2>nul
  if %errorlevel%==0 (
    set "PYTHON_CMD=python"
  ) else (
    where python3 >nul 2>nul
    if %errorlevel%==0 (
      set "PYTHON_CMD=python3"
    ) else (
      echo 未找到 Python，无法启动本地预览。
      echo 请先安装 Python 3，或在 Microsoft Store / python.org 安装后再双击本文件。
      pause
      exit /b 1
    )
  )
)

set "PREVIEW_PY=%TEMP%\wazuo_preview_%RANDOM%_%RANDOM%.py"

> "%PREVIEW_PY%" echo from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
>> "%PREVIEW_PY%" echo from urllib.parse import quote
>> "%PREVIEW_PY%" echo from functools import partial
>> "%PREVIEW_PY%" echo import os
>> "%PREVIEW_PY%" echo import socket
>> "%PREVIEW_PY%" echo import shutil
>> "%PREVIEW_PY%" echo import webbrowser
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo html_files = [name for name in os.listdir(".") if name.lower().endswith(".html")]
>> "%PREVIEW_PY%" echo if not html_files:
>> "%PREVIEW_PY%" echo     raise SystemExit("当前文件夹没有找到 HTML 页面，请确认已完整解压离线包。")
>> "%PREVIEW_PY%" echo html_name = html_files[0]
>> "%PREVIEW_PY%" echo for name in html_files:
>> "%PREVIEW_PY%" echo     if "预览" in name or "优化" in name:
>> "%PREVIEW_PY%" echo         html_name = name
>> "%PREVIEW_PY%" echo         break
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
>> "%PREVIEW_PY%" echo     sock.bind(("127.0.0.1", 0))
>> "%PREVIEW_PY%" echo     port = sock.getsockname()[1]
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo class Handler(SimpleHTTPRequestHandler):
>> "%PREVIEW_PY%" echo     protocol_version = "HTTP/1.1"
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo     def handle(self):
>> "%PREVIEW_PY%" echo         try:
>> "%PREVIEW_PY%" echo             super().handle()
>> "%PREVIEW_PY%" echo         except (BrokenPipeError, ConnectionResetError):
>> "%PREVIEW_PY%" echo             pass
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo     def log_message(self, *args):
>> "%PREVIEW_PY%" echo         pass
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo     def send_head(self):
>> "%PREVIEW_PY%" echo         self.range = None
>> "%PREVIEW_PY%" echo         path = self.translate_path(self.path)
>> "%PREVIEW_PY%" echo         if os.path.isdir(path):
>> "%PREVIEW_PY%" echo             return super().send_head()
>> "%PREVIEW_PY%" echo         try:
>> "%PREVIEW_PY%" echo             f = open(path, "rb")
>> "%PREVIEW_PY%" echo         except OSError:
>> "%PREVIEW_PY%" echo             self.send_error(404, "File not found")
>> "%PREVIEW_PY%" echo             return None
>> "%PREVIEW_PY%" echo         size = os.fstat(f.fileno()).st_size
>> "%PREVIEW_PY%" echo         ctype = self.guess_type(path)
>> "%PREVIEW_PY%" echo         range_header = self.headers.get("Range")
>> "%PREVIEW_PY%" echo         if range_header and range_header.startswith("bytes="):
>> "%PREVIEW_PY%" echo             start_text, _, end_text = range_header[6:].partition("-")
>> "%PREVIEW_PY%" echo             try:
>> "%PREVIEW_PY%" echo                 start = int(start_text) if start_text else 0
>> "%PREVIEW_PY%" echo                 end = int(end_text) if end_text else size - 1
>> "%PREVIEW_PY%" echo                 end = min(end, size - 1)
>> "%PREVIEW_PY%" echo                 if start ^> end:
>> "%PREVIEW_PY%" echo                     raise ValueError
>> "%PREVIEW_PY%" echo                 self.range = (start, end)
>> "%PREVIEW_PY%" echo                 self.send_response(206)
>> "%PREVIEW_PY%" echo                 self.send_header("Content-type", ctype)
>> "%PREVIEW_PY%" echo                 self.send_header("Accept-Ranges", "bytes")
>> "%PREVIEW_PY%" echo                 self.send_header("Content-Range", f"bytes {start}-{end}/{size}")
>> "%PREVIEW_PY%" echo                 self.send_header("Content-Length", str(end - start + 1))
>> "%PREVIEW_PY%" echo                 self.end_headers()
>> "%PREVIEW_PY%" echo                 f.seek(start)
>> "%PREVIEW_PY%" echo                 return f
>> "%PREVIEW_PY%" echo             except ValueError:
>> "%PREVIEW_PY%" echo                 self.send_error(416, "Requested Range Not Satisfiable")
>> "%PREVIEW_PY%" echo                 f.close()
>> "%PREVIEW_PY%" echo                 return None
>> "%PREVIEW_PY%" echo         self.send_response(200)
>> "%PREVIEW_PY%" echo         self.send_header("Content-type", ctype)
>> "%PREVIEW_PY%" echo         self.send_header("Accept-Ranges", "bytes")
>> "%PREVIEW_PY%" echo         self.send_header("Content-Length", str(size))
>> "%PREVIEW_PY%" echo         self.end_headers()
>> "%PREVIEW_PY%" echo         return f
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo     def copyfile(self, source, outputfile):
>> "%PREVIEW_PY%" echo         try:
>> "%PREVIEW_PY%" echo             if self.range:
>> "%PREVIEW_PY%" echo                 remaining = self.range[1] - self.range[0] + 1
>> "%PREVIEW_PY%" echo                 while remaining ^> 0:
>> "%PREVIEW_PY%" echo                     chunk = source.read(min(64 * 1024, remaining))
>> "%PREVIEW_PY%" echo                     if not chunk:
>> "%PREVIEW_PY%" echo                         break
>> "%PREVIEW_PY%" echo                     outputfile.write(chunk)
>> "%PREVIEW_PY%" echo                     remaining -= len(chunk)
>> "%PREVIEW_PY%" echo             else:
>> "%PREVIEW_PY%" echo                 shutil.copyfileobj(source, outputfile)
>> "%PREVIEW_PY%" echo         except (BrokenPipeError, ConnectionResetError):
>> "%PREVIEW_PY%" echo             pass
>> "%PREVIEW_PY%" echo.
>> "%PREVIEW_PY%" echo url = f"http://127.0.0.1:{port}/{quote(html_name)}"
>> "%PREVIEW_PY%" echo print("本地预览已启动：", flush=True)
>> "%PREVIEW_PY%" echo print(url, flush=True)
>> "%PREVIEW_PY%" echo print("", flush=True)
>> "%PREVIEW_PY%" echo print("请不要关闭这个窗口；关闭窗口后，本地预览也会停止。", flush=True)
>> "%PREVIEW_PY%" echo webbrowser.open(url)
>> "%PREVIEW_PY%" echo server = ThreadingHTTPServer(("127.0.0.1", port), partial(Handler, directory=os.getcwd()))
>> "%PREVIEW_PY%" echo try:
>> "%PREVIEW_PY%" echo     server.serve_forever()
>> "%PREVIEW_PY%" echo finally:
>> "%PREVIEW_PY%" echo     try:
>> "%PREVIEW_PY%" echo         os.remove(__file__)
>> "%PREVIEW_PY%" echo     except OSError:
>> "%PREVIEW_PY%" echo         pass

%PYTHON_CMD% "%PREVIEW_PY%"
set "EXIT_CODE=%errorlevel%"
if not "%EXIT_CODE%"=="0" (
  echo.
  echo 启动失败，请确认离线包已先解压，并且 Python 3 可正常运行。
  pause
)
exit /b %EXIT_CODE%
