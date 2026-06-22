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
