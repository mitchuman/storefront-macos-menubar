#!/usr/bin/env python3
"""Replace Storefront app version strings in Sanity (esz74z9f / production).

Usage:
  python3 update-sanity-version.py <OLD> <NEW>

Accepts versions with or without a leading \"v\" (e.g. 0.0.7 or v0.0.7).
Replaces both bare and v-prefixed forms across all non-draft documents.
Auth: ~/.config/sanity/config.json → authToken

Exits non-zero if any OLD strings remain after mutation.
"""

from __future__ import annotations

import copy
import json
import pathlib
import re
import sys
import urllib.parse
import urllib.request

PROJECT = "esz74z9f"
DATASET = "production"
API = f"https://{PROJECT}.api.sanity.io/v2024-01-01/data"


def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(code)


def normalize(raw: str) -> str:
    s = raw.strip()
    if s.startswith("v") or s.startswith("V"):
        s = s[1:]
    if not re.fullmatch(r"\d+\.\d+\.\d+", s):
        die(f"expected semver like 0.0.7, got {raw!r}")
    return s


def load_token() -> str:
    path = pathlib.Path.home() / ".config" / "sanity" / "config.json"
    if not path.is_file():
        die(f"missing Sanity CLI config at {path} (run: sanity login)")
    cfg = json.loads(path.read_text())
    token = cfg.get("authToken")
    if not token:
        die(f"no authToken in {path}")
    return token


def api_get(token: str, query: str):
    url = f"{API}/query/{DATASET}?query=" + urllib.parse.quote(query)
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)["result"]


def api_mutate(token: str, mutations: list):
    url = f"{API}/mutate/{DATASET}?returnIds=true&returnDocuments=false"
    body = json.dumps({"mutations": mutations}).encode()
    req = urllib.request.Request(
        url,
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req) as resp:
        return json.load(resp)


def replace_in(obj, old_bare: str, new_bare: str) -> bool:
    """Replace vOLD/OLD with vNEW/NEW in all strings. Returns True if changed."""
    old_v, new_v = f"v{old_bare}", f"v{new_bare}"
    changed = False

    if isinstance(obj, dict):
        for k, v in list(obj.items()):
            if isinstance(v, str):
                nv = v.replace(old_v, new_v).replace(old_bare, new_bare)
                if nv != v:
                    obj[k] = nv
                    changed = True
            else:
                if replace_in(v, old_bare, new_bare):
                    changed = True
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, str):
                nv = v.replace(old_v, new_v).replace(old_bare, new_bare)
                if nv != v:
                    obj[i] = nv
                    changed = True
            else:
                if replace_in(v, old_bare, new_bare):
                    changed = True
    return changed


def find_docs_with(docs: list, pattern: re.Pattern) -> list[tuple[str, str | None, str | None]]:
    hits = []
    for doc in docs:
        if pattern.search(json.dumps(doc)):
            hits.append((doc["_id"], doc.get("_type"), doc.get("title")))
    return hits


def strip_system_fields(doc: dict) -> dict:
    out = copy.deepcopy(doc)
    for k in list(out.keys()):
        if k in ("_rev", "_updatedAt", "_createdAt"):
            del out[k]
    return out


def main(argv: list[str]) -> None:
    if len(argv) != 3 or argv[1] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        raise SystemExit(0 if len(argv) == 2 else 2)

    old_bare = normalize(argv[1])
    new_bare = normalize(argv[2])
    if old_bare == new_bare:
        die("OLD and NEW are the same")

    token = load_token()
    print(f"Sanity {PROJECT}/{DATASET}: {old_bare} → {new_bare}")

    docs = api_get(token, '*[!(_id in path("drafts.**"))]')
    old_pat = re.compile(rf"v?{re.escape(old_bare)}")
    before = find_docs_with(docs, old_pat)
    if not before:
        print(f"No documents contain {old_bare!r} / {('v' + old_bare)!r}. Nothing to do.")
        # Still verify NEW is not required to exist beforehand
        raise SystemExit(0)

    print(f"Found {len(before)} document(s) with old version:")
    for _id, _type, title in before:
        print(f"  {_id}  {_type}  {title!r}")

    mutations = []
    for doc in docs:
        if not old_pat.search(json.dumps(doc)):
            continue
        updated = strip_system_fields(doc)
        if not replace_in(updated, old_bare, new_bare):
            continue
        mutations.append({"createOrReplace": updated})

    if not mutations:
        die("matched docs but no string replacements applied (unexpected)")

    result = api_mutate(token, mutations)
    print("Mutate result:")
    print(json.dumps(result, indent=2))

    after_docs = api_get(token, '*[!(_id in path("drafts.**"))]')
    remaining = find_docs_with(after_docs, old_pat)
    new_pat = re.compile(rf"v?{re.escape(new_bare)}")
    with_new = find_docs_with(after_docs, new_pat)

    print(f"Documents with v{new_bare}: {len(with_new)}")
    for _id, _type, title in with_new:
        print(f"  {_id}  {_type}  {title!r}")

    if remaining:
        print("Remaining old version hits:", file=sys.stderr)
        for _id, _type, title in remaining:
            print(f"  {_id}  {_type}  {title!r}", file=sys.stderr)
        die("old version strings still present after mutate")

    print("OK — no remaining old version strings.")


if __name__ == "__main__":
    main(sys.argv)
