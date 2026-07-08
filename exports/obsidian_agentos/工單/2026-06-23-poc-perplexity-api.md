---
type: agentos-task
dispatch_id: "2026-06-23-poc-perplexity-api"
status: "已完成"
route_to: "未標示"
governance_version: "legacy"
updated_at: "2026-06-22 21:13"
source_of_truth: "E:\\AgentOS\\data\\codex_tasks\\2026-06-23-poc-perplexity-api\\TASK.md"
generated_read_only: true
---

# TASK: Proof of Concept for nathanrchn/perplexityai

> [!warning] 衍生檢視
> 本筆記由 AgentOS 自動產生。唯一真相來源是 `E:\AgentOS\data\codex_tasks\2026-06-23-poc-perplexity-api\TASK.md`，請勿以本筆記反向覆寫工單。

## 宇宙連結

- 中心：[[AgentOS 工單宇宙]]
- 狀態：[[狀態/已完成]]
- 路由：[[角色/未標示]]
- 治理：[[共同治理 vlegacy]]

## 工單資料

- 工單號：`2026-06-23-poc-perplexity-api`
- 狀態：已完成
- 路由：未標示
- 更新時間：2026-06-22 21:13
- 原始工單：`E:\AgentOS\data\codex_tasks\2026-06-23-poc-perplexity-api\TASK.md`
- 結果檔案：`E:\AgentOS\data\codex_tasks\2026-06-23-poc-perplexity-api\OUTPUTS\RESULT.md`

## 原始工單

# TASK: Proof of Concept for nathanrchn/perplexityai

## Objective
Verify the basic functionality of the `perplexityai` Python library for future integration as an AgentOS tool.

## Steps
1. **Setup**: Create a temporary Python virtual environment.
2. **Install**: Install the `perplexityai` library using pip.
3. **Script**: Write a minimal Python script (`test_perplexity.py`) that:
    a. Imports the necessary components from the library.
    b. Executes a simple search query, for example: "What is the capital of Taiwan?".
    c. Prints the search results to the console.
4. **API Keys**: The library may require an API key. For this PoC, it's acceptable to assume a `PERPLEXITY_API_KEY` environment variable might be needed. If the library uses session cookies or other methods, document the findings. **Do not commit any real keys to the repository.**
5. **Execute**: Run the script and capture the output.

## Acceptance Criteria
- The `perplexityai` library installs successfully.
- The test script runs without crashing.
- The output contains a plausible answer from Perplexity AI.
- The method for authentication (API key, session, etc.) is identified.

## Output
- Create `OUTPUTS/RESULT.md` with the following ASCII key=value pairs:
  - `POC_STATUS`: SUCCESS | FAILURE
  - `AUTHENTICATION_METHOD`: API_KEY | SESSION_COOKIE | OTHER | UNKNOWN
  - `OUTPUT_SNIPPET`: A brief snippet of the console output from the test script.
  - `NOTE`: Any observations or difficulties encountered.


## 進度與實際變更

POC_STATUS=FAILURE
AUTHENTICATION_METHOD=API_KEY
OUTPUT_SNIPPET=perplexity.PerplexityError: The api_key client option must be set either by passing api_key to the client or by setting the PERPLEXITY_API_KEY environment variable
NOTE=The library installed successfully but requires a PERPLEXITY_API_KEY environment variable. The PoC failed at the execution step due to the missing key. The next step is to obtain an API key and re-run the test.

