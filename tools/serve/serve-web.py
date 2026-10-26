"""G06 — Static server cho artifact Web (test tren thiet bi that).

MIME application/wasm la BAT BUOC: WebAssembly.instantiateStreaming se tu choi
neu Content-Type khong dung.

Dung:
    python tools/serve/serve-web.py <dir> [port] [bind]
"""
import gzip
import http.server
import os
import socket
import socketserver
import sys

MIME = {
    ".wasm": "application/wasm",
    ".pck": "application/octet-stream",
    ".js": "text/javascript",
    ".mjs": "text/javascript",
    ".html": "text/html; charset=utf-8",
    ".css": "text/css; charset=utf-8",
    ".json": "application/json",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".webp": "image/webp",
    ".ico": "image/x-icon",
}


# Bat che do nen bang bien moi truong H5_SERVE_GZIP=1.
# Khi bat, server nen dong (gzip) cho .wasm/.js/.pck de mo phong hosting that.
# Muc dich: do dung "bytes truyen" nhu production, khong phai kich thuoc file tren dia.
GZIP_ENABLED = os.environ.get("H5_SERVE_GZIP", "0") == "1"
GZIP_TYPES = {".wasm", ".js", ".pck", ".html", ".css", ".json", ".svg"}


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=os.environ["H5_SERVE_DIR"], **kwargs)

    def do_GET(self):
        if not GZIP_ENABLED:
            return super().do_GET()
        path = self.translate_path(self.path)
        if not os.path.isfile(path):
            return super().do_GET()
        ext = os.path.splitext(path)[1].lower()
        if ext not in GZIP_TYPES:
            return super().do_GET()
        if "gzip" not in self.headers.get("Accept-Encoding", ""):
            return super().do_GET()

        with open(path, "rb") as f:
            raw = f.read()
        body = gzip.compress(raw, 6)
        self.send_response(200)
        self.send_header("Content-Type", self.guess_type(path))
        self.send_header("Content-Encoding", "gzip")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def guess_type(self, path):
        ext = os.path.splitext(str(path))[1].lower()
        if ext in MIME:
            return MIME[ext]
        return super().guess_type(path)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))
        sys.stderr.flush()


class Reuse(socketserver.ThreadingTCPServer):
    # G05: KHONG cho chiem chung port. Tren Windows SO_REUSEADDR cho phep hai
    # socket bind cung port -> preview co the noi chuyen voi server la.
    # Dung SO_EXCLUSIVEADDRUSE de bind THAT BAI neu port da co nguoi giu.
    allow_reuse_address = False
    daemon_threads = True

    def server_bind(self):
        if hasattr(socket, "SO_EXCLUSIVEADDRUSE"):
            self.socket.setsockopt(socket.SOL_SOCKET, socket.SO_EXCLUSIVEADDRUSE, 1)
        super().server_bind()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("usage: python serve-web.py <dir> [port] [bind]")
        sys.exit(2)
    directory = os.path.abspath(sys.argv[1])
    port = int(sys.argv[2]) if len(sys.argv) > 2 else 8060
    bind = sys.argv[3] if len(sys.argv) > 3 else "0.0.0.0"
    if not os.path.isdir(directory):
        print("Khong tim thay thu muc: " + directory)
        sys.exit(2)
    os.environ["H5_SERVE_DIR"] = directory
    print("=== H5 static server ===")
    print("dir  : " + directory)
    print("bind : " + bind + ":" + str(port))
    print("MIME : .wasm -> application/wasm, .pck -> application/octet-stream")
    print("GZIP : " + ("BAT (mo phong hosting that)" if GZIP_ENABLED else "tat (H5_SERVE_GZIP=1 de bat)"))
    print("URL  : http://localhost:" + str(port) + "/")
    print("")
    print("Test tren dien thoai: mo tunnel HTTPS tro toi port nay")
    print("  cloudflared tunnel --url http://localhost:" + str(port))
    print("  ngrok http " + str(port))
    print("")
    print("LUU Y: http://IP-LAN-PC KHONG tuong duong localhost (secure context).")
    print("Ctrl+C de dung.")
    sys.stdout.flush()
    # G05: tu choi neu da co process khac nghe port nay (ke ca 0.0.0.0 vs 127.0.0.1).
    for probe_host in ("127.0.0.1", "::1"):
        fam = socket.AF_INET6 if ":" in probe_host else socket.AF_INET
        try:
            with socket.socket(fam, socket.SOCK_STREAM) as s:
                s.settimeout(0.5)
                if s.connect_ex((probe_host, port)) == 0:
                    print("LOI: port " + str(port) + " da co process khac nghe (" + probe_host + "). Chon port khac.")
                    sys.stdout.flush()
                    sys.exit(3)
        except OSError:
            pass
    try:
        httpd_ctx = Reuse((bind, port), Handler)
    except OSError as e:
        print("LOI: khong bind duoc port " + str(port) + ": " + str(e))
        sys.stdout.flush()
        sys.exit(3)
    with httpd_ctx as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nDa dung.")