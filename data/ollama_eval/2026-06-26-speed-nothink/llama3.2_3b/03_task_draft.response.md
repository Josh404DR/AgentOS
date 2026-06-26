# AgentOS TASK
## Task ID: [Insert ID]
## Description:

Normalize 5 messy Telegram reports into key=value status.

### Constraints:
- No external access to Telegram API or database.
- No cleanup of existing data.
- No customer messages allowed.

### Objective:
Transform the input reports into a standardized format, resulting in a clean and readable output.

### Steps:
1. Parse each report using a custom parser.
2. Extract key-value pairs from the parsed reports.
3. Normalize the extracted data by removing unnecessary characters and formatting.
4. Store the normalized data in a temporary file.
5. Create a new RESULT.md file with the standardized data.

### Expected Output:
A clean and formatted RESULT.md file containing the normalized data.

### Notes:
- This task assumes that the input reports are in a specific format, which may need to be adjusted if the reports change.
- The output will be a static file, not sent to any external system.