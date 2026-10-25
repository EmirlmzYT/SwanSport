#!/usr/bin/env python3
"""Serve the built console on loopback, including GoRouter deep links."""

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit


class ConsoleHandler(SimpleHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        if not Path(path).suffix and not Path(self.translate_path(path)).is_file():
            self.path = "/index.html"
        super().do_GET()

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", type=int, default=55440)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    directory = root / "apps/swansport_console/build/local-console"
    if not (directory / "index.html").is_file():
        parser.error("Build apps/swansport_console into build/local-console first.")
    handler = partial(ConsoleHandler, directory=str(directory))
    server = ThreadingHTTPServer(("127.0.0.1", args.port), handler)
    print(f"SwanSport Konsol: http://localhost:{args.port}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
