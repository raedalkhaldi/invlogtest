"""Local development server - serves the dist directory on port 8080."""
import http.server
import os

os.chdir(os.path.join(os.path.dirname(__file__), "dist"))
print("Serving at http://localhost:8080")
http.server.test(HandlerClass=http.server.SimpleHTTPRequestHandler, port=8080)
