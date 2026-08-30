#!/usr/bin/env python3
import json
import sys
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_RAW_PREFIX = "/T1Legendary/nekobox-routing-profiles/main/"
ALLOWED_DEFAULTS = {"direct", "proxy"}
ALLOWED_OUTBOUNDS = {"direct", "proxy", "block"}


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"{path.relative_to(ROOT)}: {error}")


catalog = load_json(ROOT / "catalog.json")
profiles = catalog.get("profiles")
if catalog.get("schema_version") != 1 or not isinstance(profiles, list):
    fail("catalog.json must contain schema_version=1 and a profiles array")

seen_ids = set()
for item in profiles:
    profile_id = item.get("id")
    name = item.get("name")
    url = item.get("url")
    default_outbound = item.get("default_outbound")

    if not isinstance(profile_id, str) or not profile_id:
        fail("every catalog profile must have a non-empty string id")
    if profile_id in seen_ids:
        fail(f"duplicate profile id: {profile_id}")
    seen_ids.add(profile_id)
    if not isinstance(name, str) or not name:
        fail(f"{profile_id}: name must be a non-empty string")
    if default_outbound not in ALLOWED_DEFAULTS:
        fail(f"{profile_id}: default_outbound must be direct or proxy")

    parsed_url = urlparse(url) if isinstance(url, str) else None
    if not parsed_url or parsed_url.scheme != "https" or parsed_url.netloc != "raw.githubusercontent.com":
        fail(f"{profile_id}: url must use raw.githubusercontent.com over HTTPS")
    if not parsed_url.path.startswith(EXPECTED_RAW_PREFIX):
        fail(f"{profile_id}: url points outside this repository")

    relative_path = parsed_url.path.removeprefix(EXPECTED_RAW_PREFIX)
    profile_path = ROOT / relative_path
    rules = load_json(profile_path)
    if not isinstance(rules, list) or not rules:
        fail(f"{relative_path}: profile must be a non-empty JSON array")

    for index, rule in enumerate(rules, start=1):
        if not isinstance(rule, dict) or not isinstance(rule.get("action"), str):
            fail(f"{relative_path}: rule #{index} must be an object with action")
        outbound = rule.get("outbound")
        if outbound is not None and outbound not in ALLOWED_OUTBOUNDS:
            fail(f"{relative_path}: rule #{index} has unsupported outbound {outbound!r}")

print(f"Validated {len(profiles)} routing profiles")
