#!/usr/bin/env bash
set -euo pipefail

# 1. Merge all requirements into a raw file
find ./ComfyUI/custom_nodes -type f -name "requirements.txt" \
  -exec cat {} + | sort -u > all-requirements-raw.txt

# 2. Dynamic cleanup into all-requirements.txt
# Remove bad/conflicting pins
grep -viE '^(deepspeed|tensorflow==2\.6\.2|numpy==1\.20\.3|tensorflow-addons==0\.15\.0|tensorboardx==0|opencv-python-headless==)' \
  all-requirements-raw.txt > all-requirements-cleaned.txt || true

# Deduplicate by package (keep last occurrence, e.g. the loosest constraint)
awk -F'[<>= ]' '
  {
    pkg=tolower($1)
    line[$1]=$0
  }
  END {
    for (p in line) print line[p]
  }
' all-requirements-cleaned.txt | sort -u > all-requirements.txt

# Force modern, compatible versions at the end
echo "numpy>=2.0.0,<2.3.0" >> all-requirements.txt
echo "opencv-python-headless==4.12.0.88" >> all-requirements.txt
echo "tensorflow>=2.16.0" >> all-requirements.txt
# echo "tensorflow-addons>=0.23.0" >> all-requirements.txt
echo "tensorboardX==2.6.4" >> all-requirements.txt

# 3. Upgrade pip + build tools
python3 -m pip install --upgrade pip setuptools wheel build

# 4. Install everything
pip install -r all-requirements.txt
