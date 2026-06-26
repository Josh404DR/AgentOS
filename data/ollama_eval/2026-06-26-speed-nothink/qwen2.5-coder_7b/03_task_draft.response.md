# AgentOS TASK.md Draft

## Goal
Normalize 5 messy Telegram reports into a key=value status format.

## Constraints
- No external access
- No cleanup
- No customer messages

## Input
- 5 messy Telegram reports (files or text)

## Output
- RESULT.md containing the normalized status in key=value pairs

## Steps
1. Read each of the 5 Telegram reports.
2. Extract relevant information and convert it into key=value format.
3. Ensure all keys are unique and values are clear.
4. Write the normalized data to RESULT.md.

## Example
**Input:**
```
Report 1:
Status: Active
User: John Doe
Date: 2023-04-01

Report 2:
Active, User=Jane Smith, Date=2023-04-02
```

**Output (RESULT.md):**
```
status=Active
user=John Doe
date=2023-04-01
status=Active
user=Jane Smith
date=2023-04-02
```

## Notes
- Ensure the format is consistent across all reports.
- Handle any inconsistencies in data types (e.g., dates, booleans) appropriately.