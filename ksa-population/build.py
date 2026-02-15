"""
build.py - Build script for Cloudflare Pages deployment
Fetches data from the API and prepares the static site in the 'dist' directory.
"""

import os
import shutil
import subprocess
import sys


def main():
    project_dir = os.path.dirname(os.path.abspath(__file__))
    dist_dir = os.path.join(project_dir, "dist")

    print("=" * 50)
    print("Building KSA Population Analysis Site")
    print("=" * 50)

    # Step 1: Fetch data from API
    print("\n[1/3] Fetching data from DataSaudi API...")
    subprocess.check_call([sys.executable, os.path.join(project_dir, "fetch_data.py")])

    # Step 2: Create dist directory
    print("\n[2/3] Preparing dist directory...")
    if os.path.exists(dist_dir):
        shutil.rmtree(dist_dir)
    os.makedirs(dist_dir)

    # Step 3: Copy static files to dist
    print("\n[3/3] Copying static files...")
    static_dir = os.path.join(project_dir, "static")
    for item in os.listdir(static_dir):
        src = os.path.join(static_dir, item)
        dst = os.path.join(dist_dir, item)
        if os.path.isdir(src):
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)

    print(f"\nBuild complete! Output directory: {dist_dir}")
    print("Files:")
    for root, dirs, files in os.walk(dist_dir):
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), dist_dir)
            print(f"  {rel}")


if __name__ == "__main__":
    main()
