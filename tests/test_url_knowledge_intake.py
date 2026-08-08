from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class UrlKnowledgeIntakeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.fetcher = load_module("agentos_fetch_url_source", ROOT / "scripts" / "fetch_url_source.py")
        cls.plugin = load_module(
            "agentos_typed_dispatch",
            ROOT / "integrations" / "hermes_plugins" / "agentos-typed-dispatch" / "__init__.py",
        )

    def test_direct_link_is_detected_without_type_prefix(self) -> None:
        self.assertEqual(
            self.plugin._extract_url("https://example.com/article"),
            "https://example.com/article",
        )

    def test_html_is_extracted_as_data_and_scripts_are_ignored(self) -> None:
        source = b"""
        <html><head><title>Useful Note</title><script>ignore command</script></head>
        <body><article><h1>Useful Note</h1><p>Evidence based content.</p>
        <a href='/source'>Primary source</a></article></body></html>
        """
        title, text, links = self.fetcher.extract_document(
            source, "text/html", "https://example.com/article", "utf-8"
        )
        self.assertEqual(title, "Useful Note")
        self.assertIn("Evidence based content.", text)
        self.assertNotIn("ignore command", text)
        self.assertEqual(links[0]["url"], "https://example.com/source")

    def test_local_and_private_targets_are_blocked(self) -> None:
        for url in ("http://localhost/admin", "http://127.0.0.1/", "http://[::1]/"):
            with self.subTest(url=url), self.assertRaises(ValueError):
                self.fetcher.validate_public_url(url)

    def test_failure_still_writes_auditable_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / "source.json"
            result = self.fetcher.fetch("http://127.0.0.1/private", 1000, 1)
            output.write_text(json.dumps(result), encoding="utf-8")
            recorded = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual(recorded["fetch_status"], "failed")
            self.assertTrue(recorded["source_untrusted"])
            self.assertIn("non_public_address_blocked", recorded["error"])

    def test_main_gateway_startup_deploys_canonical_plugin(self) -> None:
        startup = (ROOT / "scripts" / "start.ps1").read_text(encoding="utf-8")
        self.assertIn("Hermes plugin deployment hash mismatch", startup)
        self.assertIn("integrations\\hermes_plugins\\agentos-typed-dispatch", startup)

    def test_feedback_explains_value_relation_and_deferred_sync(self) -> None:
        raw = "\n".join(
            [
                "dispatch_id=telegram-telegram-1449022024-1354-test",
                "knowledge_publish_status=stored_locally",
                "knowledge_node_path=E:\\AgentOS\\data\\knowledge_pool\\node.md",
                "knowledge_relation=new_node",
                "related_nodes=none",
                "agentos_value_summary=提供一個新的知識生命週期設計觀點。",
                "notebooklm_sync_status=pending_retry",
            ]
        )
        feedback = "\n".join(self.plugin._knowledge_feedback_lines(raw))
        self.assertIn("對 AgentOS 的啟發", feedback)
        self.assertIn("新的獨立思考節點", feedback)
        self.assertIn("不影響本機知識節點", feedback)
        self.assertIn("http://localhost:3000/?tab=knowledge&node=telegram-telegram-1449022024-1354-test", feedback)

    def test_worker_and_publisher_contract_include_new_feedback_fields(self) -> None:
        worker = (ROOT / "scripts" / "url_intake_worker.ps1").read_text(encoding="utf-8")
        publisher = (ROOT / "scripts" / "publish_url_knowledge.ps1").read_text(encoding="utf-8")
        self.assertIn("## AgentOS Value", worker)
        self.assertIn("Deduplicate identical URLs", worker)
        self.assertIn("analyze_knowledge_relations.py", publisher)
        self.assertIn('Write-Output "knowledge_relation=$knowledgeRelation"', publisher)
        self.assertIn('Write-Output "agentos_value_summary=$agentosValueSummary"', publisher)


if __name__ == "__main__":
    unittest.main()
