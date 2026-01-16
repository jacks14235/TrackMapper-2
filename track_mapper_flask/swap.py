#!/usr/bin/env python3
"""
Swap x/y in the "real" coordinate for a points JSON file.

Usage:
  python swap_real_xy.py input.json           # writes to input_swapped.json
  python swap_real_xy.py input.json -o out.json
  python swap_real_xy.py input.json --inplace  # replace input file
"""
import argparse
import json
import os
import tempfile

def swap_real_xy(obj):
    real = obj.get("real")
    if isinstance(real, dict) and "x" in real and "y" in real:
        real["x"], real["y"] = real["y"], real["x"]

def process_file(src_path, dest_path):
    with open(src_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    # support two common formats:
    #  - top-level array of {map:..., real:...}
    #  - top-level object containing a "pairs" list: {"pairs": [ {map:..., real:...}, ... ]}
    if isinstance(data, list):
        items_to_process = data
        output_data = data
    elif isinstance(data, dict) and isinstance(data.get("pairs"), list):
        items_to_process = data["pairs"]
        output_data = data
    else:
        raise SystemExit("Expected top-level JSON array or object with a 'pairs' list")

    for item in items_to_process:
        if isinstance(item, dict):
            swap_real_xy(item)

    # Write atomically
    dirpath = os.path.dirname(dest_path) or "."
    fd, tmp_path = tempfile.mkstemp(dir=dirpath, prefix=".tmp_swap_", suffix=".json")
    os.close(fd)
    with open(tmp_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")
    os.replace(tmp_path, dest_path)

def main():
    p = argparse.ArgumentParser(description="Swap x/y in 'real' coordinates in points JSON")
    p.add_argument("input", help="input JSON file (array of {map:..., real:...})")
    p.add_argument("-o", "--output", help="output file (default: <input>_swapped.json)")
    p.add_argument("--inplace", action="store_true", help="overwrite the input file")
    args = p.parse_args()

    input_path = args.input
    if args.inplace:
        output_path = input_path
    else:
        output_path = args.output or f"{os.path.splitext(input_path)[0]}_swapped.json"

    process_file(input_path, output_path)
    print(f"Wrote swapped file to: {output_path}")

if __name__ == "__main__":
    main()