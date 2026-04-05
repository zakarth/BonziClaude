#!/usr/bin/env python3
"""
Call the Claude Code buddy_react endpoint directly.

Reads OAuth credentials from ~/.claude/.credentials.json and companion
config from ~/.claude/.claude.json (or its latest backup).
"""

import json
import sys
import argparse
from pathlib import Path

import requests

CLAUDE_DIR = Path.home() / ".claude"
BASE_API_URL = "https://api.anthropic.com"
BETA_HEADER = "ccr-byoc-2025-07-29"


def load_credentials():
    creds_path = CLAUDE_DIR / ".credentials.json"
    with open(creds_path) as f:
        creds = json.load(f)
    oauth = creds["claudeAiOauth"]
    return oauth["accessToken"]


def load_config():
    """Load from live .claude.json or latest backup."""
    live = CLAUDE_DIR / ".claude.json"
    if live.exists():
        with open(live) as f:
            return json.load(f)
    # Fall back to latest backup
    backups = sorted(CLAUDE_DIR.glob("backups/.claude.json.backup.*"))
    if not backups:
        raise FileNotFoundError("No .claude.json or backups found")
    with open(backups[-1]) as f:
        return json.load(f)


def buddy_react(
    transcript: str,
    reason: str = "turn",
    addressed: bool = False,
    recent: list[str] | None = None,
):
    access_token = load_credentials()
    config = load_config()

    org_uuid = config["oauthAccount"]["organizationUuid"]
    companion = config["companion"]

    url = f"{BASE_API_URL}/api/organizations/{org_uuid}/claude_code/buddy_react"

    payload = {
        "name": companion["name"][:32],
        "personality": companion["personality"][:200],
        "species": companion.get("species", "rabbit"),
        "rarity": companion.get("rarity", "common"),
        "stats": companion.get("stats", {}),
        "transcript": transcript[:5000],
        "reason": reason,
        "recent": [r[:200] for r in (recent or [])],
        "addressed": addressed,
    }

    headers = {
        "Authorization": f"Bearer {access_token}",
        "anthropic-beta": BETA_HEADER,
        "Content-Type": "application/json",
    }

    resp = requests.post(url, json=payload, headers=headers, timeout=10)
    resp.raise_for_status()
    data = resp.json()
    return data.get("reaction", "").strip() or None


def main():
    parser = argparse.ArgumentParser(description="Talk to your Claude Code buddy")
    parser.add_argument(
        "transcript",
        nargs="?",
        default="User is poking around in the buddy source code, reverse-engineering how it works.",
        help="Conversation transcript to react to (default: meta self-referential prompt)",
    )
    parser.add_argument(
        "--reason",
        choices=["turn", "error", "test-fail", "large-diff", "hatch"],
        default="turn",
        help="Trigger reason (default: turn)",
    )
    parser.add_argument(
        "--addressed",
        action="store_true",
        help="Pretend the user addressed the companion by name",
    )
    parser.add_argument(
        "--recent",
        nargs="*",
        default=[],
        help="Previous bubble texts for context",
    )
    parser.add_argument(
        "--raw",
        action="store_true",
        help="Print raw JSON response instead of just the reaction",
    )
    args = parser.parse_args()

    try:
        if args.raw:
            # Show full response for debugging
            access_token = load_credentials()
            config = load_config()
            org_uuid = config["oauthAccount"]["organizationUuid"]
            companion = config["companion"]
            url = f"{BASE_API_URL}/api/organizations/{org_uuid}/claude_code/buddy_react"
            payload = {
                "name": companion["name"][:32],
                "personality": companion["personality"][:200],
                "species": companion.get("species", "rabbit"),
                "rarity": companion.get("rarity", "common"),
                "stats": companion.get("stats", {}),
                "transcript": args.transcript[:5000],
                "reason": args.reason,
                "recent": [r[:200] for r in args.recent],
                "addressed": args.addressed,
            }
            headers = {
                "Authorization": f"Bearer {access_token}",
                "anthropic-beta": BETA_HEADER,
                "Content-Type": "application/json",
            }
            resp = requests.post(url, json=payload, headers=headers, timeout=10)
            print(f"Status: {resp.status_code}")
            print(json.dumps(resp.json(), indent=2))
        else:
            reaction = buddy_react(
                transcript=args.transcript,
                reason=args.reason,
                addressed=args.addressed,
                recent=args.recent,
            )
            if reaction:
                print(f"🐇 {reaction}")
            else:
                print("(no reaction)")
    except requests.HTTPError as e:
        print(f"HTTP error: {e.response.status_code} {e.response.text}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
