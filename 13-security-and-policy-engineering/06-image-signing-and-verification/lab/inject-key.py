#!/usr/bin/env python3
"""Inject cosign.pub into the Kyverno verifyImages policy.

Replaces the __COSIGN_PUB__ placeholder line in kyverno-verify-images.yaml with the
contents of cosign.pub, preserving the placeholder's indentation so the resulting
block scalar stays valid YAML. Writes verify-images.enforced.yaml.
"""
import pathlib
import sys

template = pathlib.Path("kyverno-verify-images.yaml")
pub = pathlib.Path("cosign.pub")

if not pub.exists():
    sys.exit("cosign.pub not found — run cosign-commands.sh first.")

key_lines = pub.read_text(encoding="utf-8").strip().splitlines()
out = []
for line in template.read_text(encoding="utf-8").splitlines():
    if line.strip() == "__COSIGN_PUB__":
        indent = line[: len(line) - len(line.lstrip())]
        out.extend(indent + k for k in key_lines)
    else:
        out.append(line)

pathlib.Path("verify-images.enforced.yaml").write_text("\n".join(out) + "\n", encoding="utf-8")
print("Wrote verify-images.enforced.yaml")
