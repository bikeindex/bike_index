"""Serves /tmp/cdn/serve as cdn.jsdelivr.net on 127.0.0.1:8443 (self-signed), for the
browser that can't reach the real one. spec/support/local_chrome.rb routes it here.
"""
import http.server
import os
import ssl

ROOT = "/tmp/cdn/serve"
CERT = "/tmp/cdn/cert.pem"
KEY = "/tmp/cdn/key.pem"
JS_SUFFIXES = (".mjs", "+esm", ".js")


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()

    def guess_type(self, path):
        if path.endswith(JS_SUFFIXES):
            return "application/javascript"
        return super().guess_type(path)


os.chdir(ROOT)
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(CERT, KEY)
httpd = http.server.HTTPServer(("127.0.0.1", 8443), Handler)
httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
httpd.serve_forever()
