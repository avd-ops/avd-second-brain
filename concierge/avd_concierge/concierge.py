# Personal project, not for production, provided as is; not affiliated with the author's employer, Liquidware or Microsoft.
"""Deterministic Concierge read service (docs/v1-review.md section 4).

Exposes two model-free read operations with zero LLM token usage:
- search(question, top=10): returns ranked passages and citations across knowledge/, docs/knowledge/,
  docs/, and optional .sources/ or a private vault path, matching Search-BrainKnowledge in scripts/AvdBrain.psm1.
- facts(ids, snapshot=..., estate=...): validates requested fact IDs against contracts/fact-register.json (C15),
  refuses unknown or non-built (proposed/specified) IDs, refuses a facts store inside the public repo, and
  returns only the requested C11 facts with generatedUtc.
"""

from __future__ import annotations

import json
import re
from pathlib import Path
from typing import Any


class ConciergeError(ValueError):
    """Base error for deterministic Concierge read refusals."""


class UnknownFactError(ConciergeError):
    """Raised when a caller requests a fact ID not in contracts/fact-register.json (C15)."""


class UnbuiltFactError(ConciergeError):
    """Raised when a caller requests a fact ID whose status in C15 is proposed or specified."""


class FactsStoreError(ConciergeError):
    """Raised when the facts store is missing, invalid, or placed inside the public repo."""


WORD_RE = re.compile(r"[a-z0-9]{2,}")
HEADING_RE = re.compile(r"(?m)^#\s+(.+)$")


def _unique_words(query: str) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for match in WORD_RE.finditer(query.lower()):
        w = match.group(0)
        if w not in seen:
            seen.add(w)
            out.append(w)
    return out


def _markdown_items(root: Path, includes: list[str], prefix: str = "") -> list[dict[str, Any]]:
    root_full = root.resolve()
    items: list[dict[str, Any]] = []
    for inc in includes:
        target = root_full / inc
        if target.is_file():
            files = [target]
        elif target.is_dir():
            files = sorted(target.rglob("*.md"))
        else:
            files = []
        for f in files:
            text = f.read_text(encoding="utf-8", errors="replace")
            if not text.strip():
                continue
            rel = f.relative_to(root_full).as_posix()
            probe = f"/{rel}"
            if "/lessons/" in probe:
                kind = "lesson"
            elif "/decisions/" in probe:
                kind = "decision"
            elif "/runbooks/" in probe:
                kind = "runbook"
            else:
                kind = "doc"
            m = HEADING_RE.search(text)
            title = m.group(1).strip() if m else f.stem
            ref = f"{prefix}:{rel}" if prefix else rel
            items.append({
                "kind": kind,
                "ref": ref,
                "title": title,
                "text": text,
                "snippet": None,
            })
    return items


def search_brain(
    repo_root: Path,
    query: str,
    top: int = 10,
    vault_path: Path | None = None,
    sources_root: Path | None = None,
) -> list[dict[str, Any]]:
    """Searches knowledge/, docs/, optional .sources/ and vault_path with deterministic word matching."""
    repo_root = repo_root.resolve()
    brain = repo_root / "knowledge"
    words = _unique_words(query)
    if not words or top <= 0:
        return []

    items: list[dict[str, Any]] = []
    apps_file = brain / "catalog/apps.json"
    if apps_file.is_file():
        catalog = json.loads(apps_file.read_text(encoding="utf-8"))
        for entry in catalog.get("entries") or []:
            notes = entry.get("notes") or ""
            delivery = entry.get("delivery") or ""
            match_terms = " ".join(entry.get("match") or [])
            items.append({
                "kind": "app",
                "ref": f"knowledge/catalog/apps.json#{entry['id']}",
                "title": entry.get("product", entry["id"]),
                "text": f"{entry['id']} {entry.get('vendor', '')} {entry.get('product', '')} {match_terms} {notes}",
                "snippet": f"multi-session: {entry.get('multiSession')}; delivery: {delivery}. {notes}".strip(),
            })

    rules_dir = brain / "rules"
    if rules_dir.is_dir():
        for rule_file in sorted(rules_dir.glob("*.json")):
            rule = json.loads(rule_file.read_text(encoding="utf-8"))
            used_by = rule.get("usedBy") or ""
            values_json = json.dumps(rule.get("values") or {}, separators=(",", ":"))
            items.append({
                "kind": "rule",
                "ref": f"knowledge/rules/{rule_file.name}@v{rule.get('version', 1)}",
                "title": rule.get("title", rule_file.stem),
                "text": f"{rule.get('id', '')} {rule.get('title', '')} {used_by} {values_json}",
                "snippet": f"{rule.get('status', '')}, used by: {used_by}".strip(", "),
            })

    items.extend(_markdown_items(repo_root, ["docs", "knowledge/runbooks"]))

    if vault_path is not None and vault_path.is_dir():
        items.extend(
            _markdown_items(
                vault_path,
                ["decisions", "runbooks", "lessons", "glossary.md"],
                prefix="vault",
            )
        )

    effective_sources = sources_root if sources_root is not None else (repo_root / ".sources")
    sources_cfg = repo_root / "sources/sources.json"
    if effective_sources.is_dir() and sources_cfg.is_file():
        locks: dict[str, str] = {}
        lock_file = effective_sources / "lock.json"
        if lock_file.is_file():
            for l_entry in json.loads(lock_file.read_text(encoding="utf-8")).get("sources") or []:
                if l_entry.get("name") and l_entry.get("commit"):
                    locks[l_entry["name"]] = str(l_entry["commit"])
        for src in json.loads(sources_cfg.read_text(encoding="utf-8")).get("sources") or []:
            name = src.get("name")
            if not name:
                continue
            src_dir = effective_sources / name
            if not src_dir.is_dir():
                continue
            commit = locks.get(name, "")
            prefix = f"{name}@{commit[:7]}" if commit else name
            items.extend(_markdown_items(src_dir, list(src.get("index") or []), prefix=prefix))

    patterns = [re.compile(rf"\b{re.escape(w)}(?:s|es)?\b", re.IGNORECASE) for w in words]
    scored: list[dict[str, Any]] = []
    for item in items:
        text = item["text"]
        score = sum(1 for p in patterns if p.search(text))
        if not score:
            continue
        title = item["title"] or ""
        in_title = sum(1 for p in patterns if p.search(title))
        snippet = item["snippet"]
        if not snippet:
            body_text = re.sub(r"\A---\r?\n.*?\r?\n---\r?\n?", "", text, flags=re.DOTALL)
            best_line = ""
            best_line_score = 0
            for raw_line in body_text.splitlines():
                line = raw_line.strip()
                if not line or line.startswith("---") or line.startswith("#"):
                    continue
                l_score = sum(1 for p in patterns if p.search(line))
                if l_score > best_line_score:
                    best_line_score = l_score
                    best_line = line
            snippet = best_line
        if len(snippet) > 160:
            snippet = snippet[:157] + "..."
        scored.append({
            "score": score,
            "inTitle": in_title,
            "kind": item["kind"],
            "ref": item["ref"],
            "title": title,
            "snippet": snippet,
        })

    scored.sort(key=lambda h: (-h["score"], -h["inTitle"], h["kind"] == "doc", h["ref"]))
    return scored[:top]


def load_fact_register(repo_root: Path) -> dict[str, dict[str, Any]]:
    """Loads contracts/fact-register.json (C15) indexed by fact ID."""
    reg_path = repo_root.resolve() / "contracts/fact-register.json"
    data = json.loads(reg_path.read_text(encoding="utf-8"))
    return {f["id"]: f for f in data.get("facts") or []}


def extract_pointer(document: Any, pointer: str) -> list[Any]:
    """Extracts values matching a C15 JSON pointer (with * for array elements)."""
    segments = [s for s in pointer.strip("/").split("/") if s]
    nodes: list[Any] = [document]
    for seg in segments:
        next_nodes: list[Any] = []
        for node in nodes:
            if seg == "*":
                if isinstance(node, list):
                    next_nodes.extend(node)
            elif isinstance(node, dict) and seg in node and node[seg] is not None:
                next_nodes.append(node[seg])
        nodes = next_nodes
        if not nodes:
            return []
    return nodes


def resolve_c11_fact(snapshot: dict[str, Any], spec: dict[str, Any]) -> Any:
    """Resolves a single built C11 fact from a snapshot according to its C15 register entry."""
    pointer = spec.get("path") or ""
    values = extract_pointer(snapshot, pointer)
    aggregate = spec.get("aggregate")
    if aggregate == "count":
        total = 0
        for val in values:
            if isinstance(val, (list, dict)):
                total += len(val)
            elif isinstance(val, int):
                total += val
        return total
    if aggregate == "distinct":
        seen: list[Any] = []
        for val in values:
            items = val if isinstance(val, list) else [val]
            for item in items:
                if item not in seen:
                    seen.append(item)
        return seen
    if len(values) == 1 and spec.get("grain") in ("estate", "subscription"):
        return values[0]
    return values


class Concierge:
    """Deterministic v1 Concierge service over knowledge/, contracts/fact-register.json, and a C11 facts store."""

    def __init__(
        self,
        repo_root: Path,
        facts_root: Path | None = None,
        vault_path: Path | None = None,
        sources_root: Path | None = None,
    ) -> None:
        self.repo_root = repo_root.resolve()
        self.facts_root = facts_root.resolve() if facts_root is not None else None
        self.vault_path = vault_path.resolve() if vault_path is not None else None
        self.sources_root = sources_root.resolve() if sources_root is not None else None
        if self.facts_root is not None and self._is_inside_repo(self.facts_root):
            raise FactsStoreError(
                f"Refusing facts_root '{self.facts_root}' inside avd-second-brain: C11 snapshots belong in an external facts-only store."
            )
        self._register = load_fact_register(self.repo_root)

    def _is_inside_repo(self, candidate: Path) -> bool:
        try:
            candidate.resolve().relative_to(self.repo_root)
            return True
        except ValueError:
            return False

    def search(self, question: str, top: int = 10) -> list[dict[str, Any]]:
        """Returns ranked passages with citations (never prose generation)."""
        return search_brain(
            self.repo_root,
            query=question,
            top=top,
            vault_path=self.vault_path,
            sources_root=self.sources_root,
        )

    def _load_snapshot(self, snapshot: dict[str, Any] | Path | None, estate: str | None) -> dict[str, Any]:
        if isinstance(snapshot, dict):
            doc = snapshot
        elif isinstance(snapshot, Path):
            if self._is_inside_repo(snapshot):
                raise FactsStoreError(
                    f"Refusing snapshot '{snapshot}' inside avd-second-brain: C11 snapshots belong in an external facts-only store."
                )
            doc = json.loads(snapshot.read_text(encoding="utf-8"))
        elif self.facts_root is not None:
            target_dir = (self.facts_root / estate) if estate else self.facts_root
            candidates = sorted(target_dir.rglob("*.json")) if target_dir.is_dir() else []
            if not candidates:
                raise FactsStoreError(f"No C11 snapshot found in facts store '{target_dir}'.")
            doc = json.loads(candidates[-1].read_text(encoding="utf-8"))
        else:
            raise FactsStoreError("No C11 snapshot or facts_root configured.")

        if doc.get("schema") != "avd-current-state-facts/v1":
            raise FactsStoreError(
                f"Expected schema 'avd-current-state-facts/v1', got {doc.get('schema')!r}."
            )
        return doc

    def facts(
        self,
        ids: list[str],
        snapshot: dict[str, Any] | Path | None = None,
        estate: str | None = None,
    ) -> dict[str, Any]:
        """Returns only the requested built C11 facts by C15 register ID, with generatedUtc.

        Step 2 exit check (docs/v1-review.md section 4):
        - Refuses empty ID lists, unknown IDs, and proposed/specified IDs before reading any snapshot.
        - Returns only the requested IDs.
        """
        if not isinstance(ids, list) or not ids or not all(isinstance(i, str) and i.strip() for i in ids):
            raise ConciergeError("facts(ids) requires a non-empty list of fact register IDs.")

        specs: list[tuple[str, dict[str, Any]]] = []
        for fid in ids:
            if fid.startswith("proposed:"):
                raise UnbuiltFactError(f"Fact ID {fid!r} is proposed and not built yet.")
            spec = self._register.get(fid)
            if spec is None:
                raise UnknownFactError(f"Unknown fact ID {fid!r}: not in contracts/fact-register.json.")
            status = spec.get("status")
            if status != "built":
                raise UnbuiltFactError(
                    f"Fact ID {fid!r} has status {status!r} in contracts/fact-register.json; only 'built' facts may be read."
                )
            if spec.get("contract") != "C11":
                raise UnbuiltFactError(
                    f"Fact ID {fid!r} belongs to contract {spec.get('contract')!r}; v1 Concierge serves C11 facts only."
                )
            specs.append((fid, spec))

        doc = self._load_snapshot(snapshot, estate)
        resolved = {fid: resolve_c11_fact(doc, spec) for fid, spec in specs}
        return {
            "schema": "avd-concierge-facts/v1",
            "estate": doc.get("estate"),
            "generatedUtc": doc.get("generatedUtc"),
            "facts": resolved,
        }
