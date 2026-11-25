"""Verify the full visual project assets or import them from the provided ZIP."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = json.loads((ROOT / "asset-manifest.json").read_text())
def destination(name):
    for theme in ("Blue", "Red"):
        name = name.replace(f"/{theme}.imageset/art.png", f"/Full{theme}.imageset/art.png")
    return ROOT / name

def verify():
    missing = []
    for name, digest in MANIFEST.items():
        p = destination(name)
        if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest() != digest:
            missing.append(name)
    for name in missing:
        print("MISSING OR INVALID:", name)
    return not missing

def import_zip(filename):
    with zipfile.ZipFile(filename) as z:
        data = {name: z.read(name) for name in MANIFEST}
    for name, digest in MANIFEST.items():
        if hashlib.sha256(data[name]).hexdigest() != digest:
            raise SystemExit("Invalid resource: " + name)
    for name, content in data.items():
        path = destination(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        if path.suffix == ".png":
            (path.parent / "Contents.json").write_text(json.dumps({"images":[{"filename":"art.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}))
    print("Imported all verified assets.")

if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--zip")
    p.add_argument("--allow-missing", action="store_true")
    args = p.parse_args()
    if args.zip:
        import_zip(args.zip)
    ok = verify()
    print("FULL ASSETS VERIFIED" if ok else "STATIC FALLBACK ONLY")
    raise SystemExit(0 if ok or args.allow_missing else 1)
