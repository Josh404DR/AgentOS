# Daily Lead Scout

This file is a pointer to the canonical lead workflow in `E:\AgentOS\workflows\ai_freelancer_os.md`.

Hermes already owns real lead discovery through the `daily-upwork-lead-patrol` cron job. Do not create a second lead scout agent from this file.

## Required Output

Daily patrol writes:

```text
E:\AgentOS\data\leads\YYYY-MM-DD.md
```

The file should include qualified leads, rejected/no-match notes, search terms, and a recommended next action. Hermes then sends Josh a Telegram summary with the saved path.

## Next Step

Screening consumes that daily file and appends decisions to:

```text
E:\AgentOS\data\screening\screening_log.md
```
