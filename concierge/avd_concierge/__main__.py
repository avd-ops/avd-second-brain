# Personal project, not for production, provided as is; not affiliated with the author's employer, Liquidware or Microsoft.
"""CLI entrypoint for the v1 deterministic Concierge (python3 -m avd_concierge)."""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

from .concierge import Concierge, ConciergeError
from .server import serve


def main(argv: list[str] | None = None) -> int:
    default_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(prog="avd_concierge", description="v1 deterministic Concierge read service")
    parser.add_argument("--repo-root", type=Path, default=Path(os.environ.get("BRAIN_REPO_ROOT", default_root)))
    parser.add_argument(
        "--facts-root",
        type=Path,
        default=Path(os.environ["BRAIN_FACTS_ROOT"]) if os.environ.get("BRAIN_FACTS_ROOT") else None,
    )
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_search = sub.add_parser("search", help="Search knowledge/, docs/ and connected sources with citations")
    p_search.add_argument("question", help="Search query")
    p_search.add_argument("--top", type=int, default=10, help="Maximum hits to return")

    p_facts = sub.add_parser("facts", help="Read built C11 facts by C15 register ID")
    p_facts.add_argument("--snapshot", type=Path, help="Path to C11 avd-current-state-facts/v1 JSON file")
    p_facts.add_argument("--estate", help="Estate pseudonym under --facts-root")
    p_facts.add_argument("ids", nargs="+", help="C15 fact register IDs (e.g. c11.hostPool.count)")

    p_serve = sub.add_parser("serve", help="Run the HTTP read service")
    p_serve.add_argument("--host", default=os.environ.get("CONCIERGE_HOST", "127.0.0.1"))
    p_serve.add_argument("--port", type=int, default=int(os.environ.get("CONCIERGE_PORT", "8081")))

    args = parser.parse_args(argv)
    try:
        concierge = Concierge(repo_root=args.repo_root, facts_root=args.facts_root)
        if args.cmd == "search":
            print(json.dumps({"hits": concierge.search(args.question, top=args.top)}, indent=2))
            return 0
        if args.cmd == "facts":
            result = concierge.facts(args.ids, snapshot=args.snapshot, estate=args.estate)
            print(json.dumps(result, indent=2))
            return 0
        if args.cmd == "serve":
            serve(concierge, host=args.host, port=args.port)
            return 0
    except ConciergeError as error:
        print(json.dumps({"error": str(error)}), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
