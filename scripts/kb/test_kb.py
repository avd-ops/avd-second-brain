# Adapted from nickprignano/2ndbrain (Apache-2.0) and changed for avd-second-brain; see scripts/kb/NOTICE.
"""Tests for the knowledge base scripts. Run: python3 -m unittest discover -s scripts/kb"""

from __future__ import annotations

import shutil
import sys
import tempfile
import unittest
from datetime import date
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build  # noqa: E402
import digest  # noqa: E402
import feedback  # noqa: E402
import freshness  # noqa: E402
import kblib  # noqa: E402

SAFE = "### Public-safe\n\n- [X] I removed tenant, subscription and resource IDs, names, domains, emails, IP addresses and secrets.\n"

FEEDBACK_BODY = """### Outcome

Broke or gave the wrong result

### Page

docs/knowledge/fslogix/README.md

### What happened

The SMB encryption fix needed a different setting name.

### Versions

_No response_

### Evidence

_No response_

""" + SAFE

KNOWN_ERROR_BODY = """### Symptom

`Access is denied` mounting an Azure Files share

### Cause

Renamed in a module release.

### Fix

Use the new argument name.

### Source

https://example.com/changelog

### Versions

Az.Storage 7.4.0

### Confidence

Fix worked once; the cause is a guess

""" + SAFE


class TempData(unittest.TestCase):
    """Point the data files at temporary copies so tests never touch the real KB."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.patches = []
        for name in ("KNOWN_ERRORS", "FIELD_REPORTS", "EXPERTS"):
            src = getattr(kblib, name)
            dst = self.tmp / src.name
            shutil.copy(src, dst)
            p = mock.patch.object(kblib, name, dst)
            p.start()
            self.patches.append(p)

    def tearDown(self):
        for p in self.patches:
            p.stop()
        shutil.rmtree(self.tmp)


class FeedbackTests(TempData):
    def test_parse_form(self):
        fields = feedback.parse_form(FEEDBACK_BODY)
        self.assertEqual(fields["Outcome"], "Broke or gave the wrong result")
        self.assertEqual(fields["Versions"], "")

    def test_field_report(self):
        issue = {"number": 7, "body": FEEDBACK_BODY, "labels": [{"name": "kb-feedback"}]}
        title, _ = feedback.handle(issue, "2026-10-16")
        self.assertIn("broke on fslogix/README.md", title)
        report = kblib.load_yaml(kblib.FIELD_REPORTS)["reports"][-1]
        self.assertEqual(report["page"], "fslogix/README.md")
        self.assertNotIn("versions", report)
        with self.assertRaises(feedback.FeedbackError):
            feedback.handle(issue, "2026-10-16")  # same issue twice

    def test_known_error(self):
        issue = {"number": 8, "body": KNOWN_ERROR_BODY, "labels": [{"name": "kb-known-error"}]}
        feedback.handle(issue, "2026-10-16")
        entry = kblib.load_yaml(kblib.KNOWN_ERRORS)["errors"][-1]
        self.assertEqual(entry["status"], "unverified")
        self.assertEqual(entry["source"], "https://example.com/changelog")
        self.assertTrue(kblib.KNOWN_ERRORS.read_text().startswith("# Known errors catalog"))

    def test_rejects_unticked_and_missing_page(self):
        unticked = FEEDBACK_BODY.replace("- [X]", "- [ ]")
        with self.assertRaises(feedback.FeedbackError):
            feedback.handle({"number": 9, "body": unticked, "labels": ["kb-feedback"]}, "2026-10-16")
        bad_page = FEEDBACK_BODY.replace("fslogix/README.md", "../../etc/passwd")
        with self.assertRaises(feedback.FeedbackError):
            feedback.handle({"number": 10, "body": bad_page, "labels": ["kb-feedback"]}, "2026-10-16")


NOMINATION_BODY = """### Name

Example Person

### Blog

https://example.com/blog

### YouTube channel

_No response_

### GitHub username

@octocat

### Why follow them

Writes detailed posts on AVD image builds.

""" + SAFE.replace("tenant, subscription and resource IDs, names, domains, emails, IP addresses and secrets",
                   "only included public professional links")


class NominationTests(TempData):
    def test_nomination(self):
        issue = {"number": 12, "body": NOMINATION_BODY, "labels": ["kb-source"]}
        title, _ = feedback.handle(issue, "2026-10-17")
        self.assertIn("Example Person", title)
        entry = kblib.load_yaml(kblib.EXPERTS)["experts"][-1]
        self.assertEqual(entry["status"], "nominated")
        self.assertEqual(entry["links"], {"blog": "https://example.com/blog", "github": "octocat"})
        with self.assertRaises(feedback.FeedbackError):
            feedback.handle(issue, "2026-10-17")  # same issue twice

    def test_rejects_bad_links(self):
        bad = NOMINATION_BODY.replace("https://example.com/blog", "javascript:alert(1)")
        with self.assertRaises(feedback.FeedbackError):
            feedback.handle({"number": 13, "body": bad, "labels": ["kb-source"]}, "2026-10-17")


class ExpertTierTests(unittest.TestCase):
    def entry(self, total_scores, **gates):
        g = {"original": True, "recent": True, "feed": True, "identity": True, **gates}
        names = ["relevance", "depth", "recency", "track_record", "feedability"]
        return {"gates": g, "scores": dict(zip(names, total_scores))}

    def test_tiers(self):
        self.assertEqual(kblib.expert_tier(self.entry([2, 2, 2, 2, 2])), "tracked")
        self.assertEqual(kblib.expert_tier(self.entry([3, 3, 3, 3, 3], feed=False)), "watch")
        self.assertEqual(kblib.expert_tier(self.entry([2, 1, 1, 1, 1])), "watch")
        self.assertEqual(kblib.expert_tier(self.entry([1, 1, 1, 1, 1])), "declined")
        self.assertEqual(kblib.expert_tier(self.entry([3, 3, 3, 3, 3], identity=False)), "declined")

    def test_digest_yield(self):
        body = "### Blog A → `docs/knowledge/x.md`\n- [x] [one](https://a/1)\n- [ ] [two](https://a/2)\n### Blog B\n- [ ] [b](https://b)\n"
        counts = freshness.digest_yield([{"createdAt": "2026-10-12T13:00:00Z", "body": body},
                                         {"createdAt": "2025-01-01T13:00:00Z", "body": body}], date(2026, 9, 1))
        self.assertEqual(counts, {"Blog A": [1, 2], "Blog B": [0, 1]})


class FreshnessTests(TempData):
    def test_stale_and_reported(self):
        issue = {"number": 11, "body": FEEDBACK_BODY, "labels": ["kb-feedback"]}
        feedback.handle(issue, "2026-10-16")
        sections = freshness.collect(90, date(2027, 6, 1))
        self.assertTrue(any("fslogix/README.md" in i for i in sections["Reported broken or outdated"]))
        self.assertTrue(sections["Stale"])
        self.assertFalse(any("roadmap.md" in i for i in sections["Stale"]))  # plan pages skip


class BuildTests(unittest.TestCase):
    def test_generated_files_up_to_date(self):
        stale = [p for p, c in build.targets().items() if p.read_text(encoding="utf-8") != c]
        self.assertEqual(stale, [], "run python3 scripts/kb/build.py")

    def test_link_from(self):
        page_dir = kblib.KB_DIR / "troubleshooting"
        self.assertEqual(build.link_from(page_dir, "fslogix/README.md#x"), "../fslogix/README.md#x")
        self.assertEqual(build.link_from(page_dir, "https://example.com"), "https://example.com")


class FamilyTests(unittest.TestCase):
    FAMILY = {"format_version": 1, "projects": [
        {"id": "us", "name": "Us", "self": True, "focus": "x", "owns": ["x"]},
        {"id": "sib", "name": "Sib", "repo": "octo/sib", "kb_path": "kb", "focus": "y", "owns": ["y"]},
        {"id": "later", "name": "Later", "focus": "z", "owns": ["z"]},
    ]}

    def setUp(self):
        p = mock.patch.object(kblib, "family", lambda: self.FAMILY)
        p.start()
        self.addCleanup(p.stop)

    def test_siblings_need_a_repo(self):
        self.assertEqual([p["name"] for p in kblib.siblings()], ["Sib"])

    def test_family_items(self):
        def private(project):
            raise OSError("404")

        self.assertEqual(freshness.family_items(lambda p: {"format_version": 1}),
                         ["Later: repo not linked yet; add it to family.yaml, then its sources"])
        self.assertTrue(any("family format 2" in i for i in freshness.family_items(lambda p: {"format_version": 2})))
        self.assertTrue(any("couldn't read" in i for i in freshness.family_items(private)))

    def test_validate_wants_sibling_sources(self):
        import validate
        tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, tmp)
        (tmp / "sources.toml").write_text('[[source]]\nname = "a"\nkind = "github_commits"\nrepo = "octo/sib"\npath = "kb"\n')
        validate.errors.clear()
        with mock.patch.object(kblib, "SOURCES", tmp / "sources.toml"), mock.patch.object(validate, "ROOT", tmp):
            validate.check_family()
        self.assertEqual(len(validate.errors), 1)
        self.assertIn("kb/decisions", validate.errors[0])
        validate.errors.clear()


class LaneTests(unittest.TestCase):
    """Lanes between sibling projects (decision 0012)."""
    FAMILY = {"format_version": 1, "projects": [
        {"id": "us", "name": "Us", "self": True, "repo": "octo/us", "focus": "x", "owns": ["x"], "claude_project": "Us",
         "not_here": [{"topic": "HCL. Bicep only here", "owner": "sib", "keywords": ["terraform", "packer"],
                       "files": ["*.tf", "*.hcl"]}]},
        {"id": "sib", "name": "Sib", "repo": "octo/sib", "focus": "y", "owns": ["y"], "claude_project": "Sib"},
    ]}

    def test_lanes_match_whole_keywords(self):
        self.assertEqual([o["id"] for _, o in kblib.lanes("Packer image build", self.FAMILY)], ["sib"])
        self.assertEqual(kblib.lanes("packers and terraforming", self.FAMILY), [])

    def test_validate_refuses_files_in_another_lane(self):
        import validate
        validate.errors.clear()
        validate.check_lanes(self.FAMILY, ["bicep/main.bicep", "infra/main.tf", ".terraform.lock.hcl"])
        self.assertEqual(len(validate.errors), 2)
        self.assertIn("belongs to sib", validate.errors[0])
        validate.errors.clear()

    def test_validate_wants_a_known_owner(self):
        import validate
        family = {"projects": [{**self.FAMILY["projects"][0], "not_here": [{"topic": "z", "owner": "nobody"}]}]}
        validate.errors.clear()
        validate.check_lanes(family, [])
        self.assertIn("isn't another project", validate.errors[0])
        validate.errors.clear()

    def test_lane_items(self):
        us, row = self.FAMILY["projects"]
        agreeing = {"projects": [{**row, "self": True}, {**us, "self": False}]}
        self.assertEqual(freshness.lane_items(us, row, agreeing), [])
        stale = {"projects": [{**row, "self": True, "owns": ["y", "x"]}, {"id": "us", "repo": "octo/us"}]}
        items = freshness.lane_items(us, row, stale)
        self.assertTrue(any("our row's `owns`" in i for i in items))
        self.assertTrue(any("its row for this KB differs on owns, claude_project" in i for i in items))
        self.assertTrue(any("both KBs claim to own 'x'" in i for i in items))
        self.assertTrue(any("no row for this KB" in i for i in freshness.lane_items(us, row, {"projects": [{**row, "self": True}]})))


class AnchorTests(unittest.TestCase):
    def test_github_slugs(self):
        body = "# A\n## Post-deployment checks with Playwright\n## 8. Deployment troubleshooting\n## A\n"
        self.assertEqual(kblib.anchors(body), {
            "a", "post-deployment-checks-with-playwright", "8-deployment-troubleshooting", "a-1"})


class RateLimitTests(unittest.TestCase):
    """GitHub search retries only rate limits; a blocked network (403 without limit headers) fails at once."""

    def _err(self, code, headers):
        import email.message
        import urllib.error
        msg = email.message.Message()
        for k, v in headers.items():
            msg[k] = v
        return urllib.error.HTTPError("https://api.github.com/search/code", code, "x", msg, None)

    def test_waits(self):
        import sources
        self.assertEqual(sources.rate_limit_wait(self._err(429, {"Retry-After": "7"}), 0), 7.0)
        self.assertEqual(sources.rate_limit_wait(self._err(429, {}), 1), 20.0)
        self.assertEqual(sources.rate_limit_wait(self._err(403, {"X-RateLimit-Remaining": "0"}), 5), 60.0)
        self.assertIsNone(sources.rate_limit_wait(self._err(403, {}), 0))
        self.assertIsNone(sources.rate_limit_wait(self._err(404, {}), 0))

    def test_retries_then_succeeds(self):
        import sources
        calls = [self._err(429, {"Retry-After": "0"}), b'{"items": []}']

        def fake(url, headers):
            item = calls.pop(0)
            if isinstance(item, Exception):
                raise item
            return item

        with mock.patch.object(sources, "http_get", side_effect=fake), mock.patch.object(sources.time, "sleep"):
            self.assertEqual(sources.github("/search/code", {"q": "x"}), {"items": []})


DIGEST_BODY = """New since 2026-10-18: **3** item(s) from 2 source(s). Tick what's worth adding to the KB, and note which page.

### Blog A → `docs/knowledge/fslogix/README.md`
- [x] [One [preview] post](https://example.com/one) · 2026-10-20
- [ ] [Two](https://example.com/two) · 2026-10-21

### Blog B
- [X] [Three](https://example.com/three) · 2026-10-22 → `docs/knowledge/images/README.md`
"""


class DigestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        for page in ("fslogix/README.md", "images/README.md"):
            (self.tmp / page).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(kblib.KB_DIR / page, self.tmp / page)
        self.patch = mock.patch.object(digest, "KB_DIR", self.tmp)
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        shutil.rmtree(self.tmp)

    def test_superseded_only_older_and_unticked(self):
        issues = [{"number": 15, "body": "- [ ] a"}, {"number": 20, "body": "- [x] a"},
                  {"number": 22, "body": "- [ ] a", "comments": [{"body": "take the first one"}]},
                  {"number": 30, "body": "- [ ] new"}, {"number": 31, "body": ""}]
        self.assertEqual(digest.superseded(issues, 30), [15])

    def test_ticked_items_and_page_override(self):
        items = digest.ticked_items(DIGEST_BODY)
        self.assertEqual([(i["title"], i["page"]) for i in items],
                         [("One [preview] post", "fslogix/README.md"), ("Three", "images/README.md")])

    def test_accept_adds_once_through_feedback(self):
        issue = {"number": 42, "body": DIGEST_BODY, "labels": [{"name": "kb-digest"}]}
        title, body = feedback.handle(issue, "2026-10-28")
        self.assertIn("2 item(s) from #42", title)
        page = (self.tmp / "fslogix/README.md").read_text(encoding="utf-8")
        self.assertIn("- [One (preview) post](https://example.com/one) (Blog A, 2026-10-20; digest #42).", page)
        self.assertNotIn("example.com/two", page)
        with self.assertRaisesRegex(feedback.FeedbackError, "already on its page"):
            feedback.handle(issue, "2026-10-28")  # a re-run adds nothing twice, and says so
        self.assertEqual((self.tmp / "fslogix/README.md").read_text(encoding="utf-8").count("example.com/one"), 1)

    def test_accept_refuses_other_files_and_authors(self):
        for page in ("../../scripts/kb/build.py", "troubleshooting/known-errors.yaml", "decisions/0001-x.md"):
            with self.assertRaisesRegex(feedback.FeedbackError, "isn't a topic page"):
                feedback.handle({"number": 1, "body": f"### A → `{page}`\n- [x] [x](https://e/x)",
                                 "labels": ["kb-digest"]}, "2026-10-28")
        with self.assertRaisesRegex(feedback.FeedbackError, "opened by someone"):
            feedback.handle({"number": 1, "body": DIGEST_BODY, "labels": ["kb-digest"],
                             "user": {"login": "someone"}}, "2026-10-28")

    def test_accept_rejects_nothing_ticked_or_no_page(self):
        with self.assertRaisesRegex(feedback.FeedbackError, "nothing is ticked"):
            feedback.handle({"number": 1, "body": "### A\n- [ ] [x](https://e/x)", "labels": ["kb-digest"]}, "2026-10-28")
        with self.assertRaisesRegex(feedback.FeedbackError, "no page"):
            feedback.handle({"number": 1, "body": "### A\n- [x] [x](https://e/x)", "labels": ["kb-digest"]}, "2026-10-28")
        with self.assertRaisesRegex(feedback.FeedbackError, "isn't a topic page"):
            feedback.handle({"number": 1, "body": "### A → `nope.md`\n- [x] [x](https://e/x)", "labels": ["kb-digest"]},
                            "2026-10-28")


class ExpertYieldWindowTests(unittest.TestCase):
    """No yield finding before any digest exists, or before one has been opened since the expert was scored."""

    def _yield(self, digests, today):
        experts = {"experts": [{"id": "e1", "name": "E1", "status": "tracked", "reviewed": "2026-10-20"}]}
        with mock.patch.object(kblib, "load_yaml", return_value=experts), \
                mock.patch.object(freshness.tomllib, "loads", return_value={"source": [{"name": "Blog A", "expert": "e1"}]}):
            return freshness.expert_items(90, today, digests)["Expert yield"]

    def test_window(self):
        self.assertEqual(self._yield([], date(2026, 10, 28)), [])
        old = [{"createdAt": "2026-10-19T13:00:00Z", "body": "### Blog B\n- [ ] [b](https://b)"}]
        self.assertEqual(self._yield(old, date(2026, 10, 28)), [])
        new = old + [{"createdAt": "2026-10-26T13:00:00Z", "body": "### Blog B\n- [ ] [b](https://b)"}]
        self.assertEqual(len(self._yield(new, date(2026, 10, 28))), 1)


class ServerErrorRetryTests(unittest.TestCase):
    """Feeds get one retry on a 5xx; a 4xx fails at once."""

    def _err(self, code):
        import urllib.error
        return urllib.error.HTTPError("https://example.com/feed", code, "x", None, None)

    def _run(self, outcomes):
        import sources
        calls = list(outcomes)

        class Resp:
            def __init__(self, data): self.data = data
            def __enter__(self): return self
            def __exit__(self, *a): return False
            def read(self): return self.data

        def fake(req, timeout):
            item = calls.pop(0)
            if isinstance(item, Exception):
                raise item
            return Resp(item)

        with mock.patch.object(sources.urllib.request, "urlopen", side_effect=fake), \
                mock.patch.object(sources.time, "sleep") as sleep:
            try:
                return sources.http_get("https://example.com/feed"), sleep.call_count
            finally:
                self.left = len(calls)

    def test_retries_one_5xx(self):
        self.assertEqual(self._run([self._err(500), b"ok"]), (b"ok", 1))

    def test_gives_up_after_one_retry(self):
        import urllib.error
        with self.assertRaises(urllib.error.HTTPError):
            self._run([self._err(502), self._err(503), b"never"])
        self.assertEqual(self.left, 1)

    def test_no_retry_on_4xx(self):
        import urllib.error
        with self.assertRaises(urllib.error.HTTPError):
            self._run([self._err(404), b"never"])
        self.assertEqual(self.left, 1)


class CommitNoiseTests(unittest.TestCase):
    def test_commit_noise_is_dropped(self):
        import sources
        from datetime import datetime, timezone
        commit = lambda msg: {"html_url": "https://e/" + msg[:5], "commit": {
            "message": msg, "committer": {"date": "2026-10-20T00:00:00Z"}}}
        with mock.patch.object(sources, "github", return_value=[
                commit("Merge pull request #1 from x"), commit("Bump pyyaml"), commit("Fix the thing")]):
            items = sources.github_commits({"repo": "o/r"}, datetime(2026, 10, 1, tzinfo=timezone.utc))
        self.assertEqual([i.title for i in items], ["Fix the thing"])


if __name__ == "__main__":
    unittest.main()
