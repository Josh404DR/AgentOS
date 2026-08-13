from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "knowledge_relations", ROOT / "scripts" / "analyze_knowledge_relations.py"
)
assert SPEC and SPEC.loader
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class KnowledgeRelationTests(unittest.TestCase):
    def test_related_candidate_links_existing_node(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pool = root / "pool"
            pool.mkdir()
            existing = pool / "evidence-knowledge.md"
            existing.write_text(
                "## Original Source\n個人知識庫將原始來源、人工確認知識與 AI Wiki 分層，保留引用證據。",
                encoding="utf-8",
            )
            candidate = root / "candidate.md"
            candidate.write_text(
                "## Summary\n知識庫分為原始來源、人工確認知識、AI 生成 Wiki，避免錯誤摘要成為事實。",
                encoding="utf-8",
            )
            result = MODULE.analyze(candidate, pool, None, 0.13)
            self.assertEqual(result["knowledge_relation"], "related")
            self.assertEqual(result["related_nodes"][0]["path"], str(existing.resolve()))

    def test_unrelated_candidate_becomes_new_node(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pool = root / "pool"
            pool.mkdir()
            (pool / "software.md").write_text(
                "## Original Source\n佇列重試、worker fallback 與程式驗證。", encoding="utf-8"
            )
            candidate = root / "candidate.md"
            candidate.write_text(
                "## Summary\n義大利麵加入番茄、羅勒與橄欖油的料理方法。", encoding="utf-8"
            )
            result = MODULE.analyze(candidate, pool, None, 0.13)
            self.assertEqual(result["knowledge_relation"], "new_node")
            self.assertEqual(result["related_nodes"], [])

    def test_candidate_can_link_to_agentos_system_reference(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            pool = root / "pool"
            pool.mkdir()
            decisions = root / "docs" / "decisions"
            decisions.mkdir(parents=True)
            reference = decisions / "ADR-memory.md"
            reference.write_text(
                "## 內容\n個人知識架構保存原始來源與證據，再形成人工確認的可信知識和可重建 Wiki。",
                encoding="utf-8",
            )
            candidate = root / "candidate.md"
            candidate.write_text(
                "## Summary\n個人知識庫分開原始來源證據、人工確認知識與可重新產生的 Wiki。",
                encoding="utf-8",
            )
            result = MODULE.analyze(candidate, pool, None, 0.13, root)
            self.assertEqual(result["knowledge_relation"], "related")
            self.assertEqual(result["related_nodes"][0]["kind"], "system_reference")


if __name__ == "__main__":
    unittest.main()
