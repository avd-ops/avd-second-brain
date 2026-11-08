# Personal project, not for production, provided as is; not affiliated with the author's employer, Liquidware or Microsoft.
"""Unit tests for the v1 deterministic Concierge (concierge/avd_concierge, docs/v1-review.md section 4)."""

from __future__ import annotations

import json
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "concierge"))

from avd_concierge import (  # noqa: E402
    Concierge,
    FactsStoreError,
    UnbuiltFactError,
    UnknownFactError,
)
from avd_concierge.server import handle_request  # noqa: E402


def sample_c11_snapshot() -> dict:
    return {
        "schema": "avd-current-state-facts/v1",
        "estate": "est-0a1b2c3d",
        "generatedUtc": "2026-11-08T09:00:00Z",
        "producer": {"name": "avd_current_state_facts.ps1", "version": "1.0.0"},
        "sources": [{"kind": "collector", "generatedUtc": "2026-11-08T08:00:00Z", "manifestSha256": "ab" * 32}],
        "subscriptions": [
            {
                "id": "sub-1a2b3c4d",
                "collectedUtc": "2026-11-08T08:00:00Z",
                "regions": ["eastus2"],
                "counts": {"avdHostPools": 2, "virtualMachines": 4},
                "hostPools": [
                    {
                        "id": "hp-2b3c4d5e",
                        "region": "eastus2",
                        "type": "Pooled",
                        "loadBalancer": "BreadthFirst",
                        "maxSessionLimit": 12,
                        "startVmOnConnect": True,
                        "sessionHosts": {
                            "total": 4,
                            "status": {"Available": 3, "Unavailable": 1},
                            "staleHeartbeat": 1,
                        },
                        "vmSizes": {"Standard_D4ads_v5": 4},
                    },
                    {
                        "id": "hp-3c4d5e6f",
                        "region": "eastus2",
                        "type": "Personal",
                        "loadBalancer": "Persistent",
                        "maxSessionLimit": 1,
                        "startVmOnConnect": False,
                        "sessionHosts": {
                            "total": 2,
                            "status": {"Available": 2, "Unavailable": 0},
                            "staleHeartbeat": 0,
                        },
                        "vmSizes": {"Standard_D2s_v5": 2},
                    },
                ],
                "virtualMachines": {"total": 6},
                "budgets": {"total": 1, "withActionGroup": 1},
            }
        ],
        "validations": [],
        "redactedValues": 0,
    }


class ConciergeSearchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.concierge = Concierge(repo_root=ROOT)

    def test_search_returns_cited_passages_across_kb_rules_and_apps(self) -> None:
        finops_hits = self.concierge.search("sandbox rag cost floor cosmos serverless", top=5)
        self.assertTrue(finops_hits)
        refs = [h["ref"] for h in finops_hits]
        self.assertIn("docs/knowledge/cost/README.md", refs)
        for hit in finops_hits:
            self.assertIn("ref", hit)
            self.assertIn("title", hit)
            self.assertIn("snippet", hit)

        app_hits = self.concierge.search("Microsoft Teams media optimization", top=10)
        self.assertTrue(any(h["kind"] in ("app", "doc", "rule") for h in app_hits))

    def test_empty_query_returns_empty_list(self) -> None:
        self.assertEqual(self.concierge.search("   "), [])


class ConciergeFactsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.concierge = Concierge(repo_root=ROOT)
        self.snapshot = sample_c11_snapshot()

    def test_returns_only_requested_built_c11_facts_with_generated_utc(self) -> None:
        requested = ["c11.hostPool.count", "c11.hostPool.type", "c11.subscription.regions"]
        result = self.concierge.facts(requested, snapshot=self.snapshot)
        self.assertEqual(result["schema"], "avd-concierge-facts/v1")
        self.assertEqual(result["estate"], "est-0a1b2c3d")
        self.assertEqual(result["generatedUtc"], "2026-11-08T09:00:00Z")
        self.assertEqual(set(result["facts"].keys()), set(requested))
        self.assertEqual(result["facts"]["c11.hostPool.count"], 2)
        self.assertEqual(result["facts"]["c11.hostPool.type"], ["Pooled", "Personal"])
        self.assertEqual(result["facts"]["c11.subscription.regions"], ["eastus2"])

    def test_refuses_unknown_fact_ids(self) -> None:
        with self.assertRaises(UnknownFactError):
            self.concierge.facts(["c11.hostPool.count", "c11.notARealFact"], snapshot=self.snapshot)

    def test_refuses_proposed_and_non_c11_fact_ids(self) -> None:
        with self.assertRaises(UnbuiltFactError):
            self.concierge.facts(["proposed:c11.sessionHost.defenderRunningMode"], snapshot=self.snapshot)
        with self.assertRaises(UnbuiltFactError):
            self.concierge.facts(["liquidware.version"], snapshot=self.snapshot)
        with self.assertRaises(UnbuiltFactError):
            self.concierge.facts(["c11.hostPool.appAttachPackages"], snapshot=self.snapshot)
        with self.assertRaises(UnbuiltFactError):
            self.concierge.facts(["c12.group.rttMsP95"], snapshot=self.snapshot)

    def test_refuses_facts_store_inside_public_repo(self) -> None:
        with self.assertRaises(FactsStoreError):
            Concierge(repo_root=ROOT, facts_root=ROOT / "knowledge")

    def test_reads_latest_snapshot_from_external_facts_store(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            store = Path(tmp)
            estate_dir = store / "est-0a1b2c3d"
            estate_dir.mkdir(parents=True)
            snap_file = estate_dir / "20261108T090000Z.json"
            snap_file.write_text(json.dumps(self.snapshot), encoding="utf-8")
            c = Concierge(repo_root=ROOT, facts_root=store)
            status, body = handle_request(
                "POST",
                "/facts",
                {"ids": ["c11.subscription.budgets.withActionGroup"], "estate": "est-0a1b2c3d"},
                c,
            )
            self.assertEqual(status, 200)
            self.assertEqual(body["facts"], {"c11.subscription.budgets.withActionGroup": 1})

            bad_status, bad_body = handle_request(
                "POST",
                "/facts",
                {"ids": ["c11.unknown.fact"]},
                c,
            )
            self.assertEqual(bad_status, 400)
            self.assertIn("Unknown fact ID", bad_body["error"])

            trav_status, trav_body = handle_request(
                "POST",
                "/facts",
                {"ids": ["c11.subscription.budgets.withActionGroup"], "estate": "../outside"},
                c,
            )
            self.assertEqual(trav_status, 400)
            self.assertIn("Invalid estate identifier", trav_body["error"])


if __name__ == "__main__":
    unittest.main()
