# Knowledge Entry: Baidu Unlimited-OCR

- **Date**: 2026-06-24
- **Title**: Baidu Unlimited-OCR: Ultra-long Document Parsing with R-SWA
- **Category**: open-source-tool, computer-vision, ocr, ai-research
- **Source**: https://www.threads.net/@aimalaysia/post/DZ8g7oRAa3k
- **GitHub**: https://github.com/baidu/Unlimited-OCR
- **HuggingFace**: https://huggingface.co/baidu/Unlimited-OCR
- **Paper**: https://arxiv.org/abs/2410.18091 (Corrected from screenshot inference)
- **Actionability**: reference_only
- **Sync Status**: pending_notebooklm

## Summary
Baidu's **Unlimited-OCR** is a state-of-the-art technology specifically designed for parsing ultra-long documents. It addresses the common limitations of LLM-based OCR systems, such as memory bloat and slow generation speeds on multi-page inputs.

### Key Innovations
- **Reference-Sliding Window Attention (R-SWA)**: A decoder-level innovation that allows efficient processing of extensive text sequences.
- **Extreme Efficiency**: Capable of processing dozens of pages in a single forward pass.
- **Cross-Domain Applicability**: The architecture is extensible to ASR (Speech) and machine translation.

## Potential Impact
- **AgentOS Document Intake**: If AgentOS needs to process thick PDF reports or long manual scans for Josh, Unlimited-OCR could be the engine that prevents context window blowouts or high API costs.
- **Workflow Automation**: Could be integrated into a "Document to Markdown" pipeline for L2/L3 knowledge sync.
