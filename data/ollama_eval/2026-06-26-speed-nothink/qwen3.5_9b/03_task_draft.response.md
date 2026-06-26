# Task: Normalize Telegram Reports to Key-Value Status

**Objective**: Convert five unstructured Telegram report files into a standardized `key=value` status format within the AgentOS environment.

**Input Sources**: Locate and ingest exactly five messy text reports containing raw operational data from local storage only. Do not attempt network access or external API calls.

**Constraints & Rules**:
1. **Isolation**: Operate strictly offline with no internet connectivity allowed.
2. **No Cleanup**: Preserve all original input files; do not delete, rename, or modify source logs before processing.
3. **Exclusion Filter**: Strictly ignore any lines containing customer messages, greetings, or non-data chatter. Extract only status indicators (e.g., `OK`, `ERROR`, `PENDING`).
4. **Format Standardization**: Parse irregular delimiters and whitespace variations to output a clean list of `key=value` pairs per report.

**Output Deliverable**: Generate a single file named `RESULT.md`. This document must contain the consolidated, normalized status data for all five reports, formatted consistently as key-value entries without markdown tables or code blocks unless necessary for clarity. Ensure no extraneous commentary is included in the final output.