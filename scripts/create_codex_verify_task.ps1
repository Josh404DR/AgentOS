# create_codex_verify_task.ps1
#
# Manually create a Codex Blind Verify child task for a Complex ticket that
# completed via codex_mode: plan.
#
# Why this script exists (2026-07-27): dispatch_task_packet.ps1's own
# New-CodexVerifyTask function only auto-runs when
# ($RouteTo -eq "Codex" -and $codexMode -eq "build") (see that script,
# ~line 796-797). For codex_mode: plan tickets where Codex did the real work
# directly instead of only decomposing into children, nothing ever calls
# New-CodexVerifyTask automatically, so the ticket sits at
# task_status/dispatch_status: completed with review_dispatch_id: not_created
# forever unless someone triggers verify-bundle + verify-child creation
# by hand. This script is that manual trigger, using the exact same bundle
# format and child TASK.md template as New-CodexVerifyTask (copied verbatim
# from dispatch_task_packet.ps1, not reimplemented from scratch), so the
# resulting "-codex-verify" child is indistinguishable from one created
# automatically.
#
# Safety note this script adds that the original function does not have:
# New-CodexVerifyTask overwrites the parent's OUTPUTS\TEST_RESULT.md with a
# sparse regex-scraped version (test_command/test_result/verification/
# evidence lines only). If the parent's real TEST_RESULT.md has richer
# content (as Codex Builder normally produces), this script backs it up to
# TEST_RESULT.full.md first so nothing is silently lost.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ParentDispatchId,
    [string]$AgentOSRoot = "E:\AgentOS",
    # Force (added 2026-07-27): re-generate the verify bundle and child TASK.md
    # even when a CODEX_VERIFY child for this parent already exists. Used to
    # regenerate a bundle that was built with stale/broken extraction logic
    # (e.g. before the impact_scope fallback and TEST_RESULT preservation
    # fixes below existed) without losing the child's prior FAILED verdict -
    # that prior RESULT.md/TEST_RESULT.md are archived under the child's
    # OUTPUTS\ATTEMPTS\<timestamp>\ folder first.
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$Utf8NoBom = [Text.UTF8Encoding]::new($false)
$TasksRoot = Join-Path $AgentOSRoot "data\codex_tasks"

function Test-LooksLikeFilePath {
    # Filters backtick-quoted spans down to plausible real file paths.
    # Added 2026-07-28 as a shared helper after the naive
    # "has a separator OR ends in .something" rule matched version strings
    # like `1.2.0`/`1.3.0` (governance_version literals frequently quoted in
    # TASK.md prose) as if they were file paths.
    param([string]$Candidate)
    if (-not $Candidate) { return $false }
    if ($Candidate -match '^\d+(\.\d+){1,3}$') { return $false }
    if ($Candidate -match '^(true|false|null|aligned)$') { return $false }
    # Guard (2026-07-28, crash found on operational-drift-triage): TASK.md
    # prose sometimes uses a backtick-quoted TEMPLATE path like
    # `data\codex_tasks\<dispatch_id>\` as a pattern description, not a real
    # file. `<`/`>` (and other Windows-illegal path characters) make
    # [IO.Path]::IsPathRooted/Join-Path throw "Illegal characters in path"
    # later in the pipeline, which - with $ErrorActionPreference = "Stop" -
    # aborted the entire script before any bundle was written. Reject these
    # before they ever become a "changed file" candidate.
    if ($Candidate -match '[<>"|]' -or ($Candidate -match '\*') ) { return $false }
    $hasSeparator = $Candidate -match '[\\/]'
    $hasKnownExt = $Candidate -match '\.(ps1|psm1|psd1|md|py|json|jsonl|txt|yml|yaml|csv|ps1xml|jsx|ts|tsx|js|cs|sql|bat|cmd)$'
    return ($hasSeparator -or $hasKnownExt)
}

function Resolve-CandidatePath {
    # Bug found 2026-07-28 on queue-active-index-optimization: TASK.md prose
    # often refers to a ticket's own deliverable evidence with a path
    # relative to THAT TICKET's own folder, e.g. "結果在
    # `OUTPUTS\BENCHMARK_RESULT.json`". The old resolution always joined
    # relative candidates against $AgentOSRoot directly, producing
    # E:\AgentOS\OUTPUTS\BENCHMARK_RESULT.json (wrong, doesn't exist) instead
    # of .../data\codex_tasks\<ParentDispatchId>\OUTPUTS\BENCHMARK_RESULT.json
    # - so real evidence Codex explicitly pointed to silently vanished from
    # the bundle, exactly the AC3 gap Verify flagged. Any candidate starting
    # with "OUTPUTS\" or "OUTPUTS/" (and not already an absolute/rooted path)
    # is now resolved against the CURRENT ticket's own folder first.
    # Fail-closed (2026-07-28, Josh: a caller forgot to wrap this in
    # try/catch, so one bad candidate still crashed the whole script even
    # after the <> guard and even after the multi-line regex fix). Never let
    # this function throw - [IO.Path]::IsPathRooted/Join-Path reject certain
    # characters (<, >, embedded newlines, a stray mid-string drive colon)
    # with "Illegal characters in path", and there is always some new prose
    # shape in a TASK.md that can produce one of those. Return $null on any
    # failure instead; every call site must treat $null as "not a real path,
    # skip it" rather than assume a string comes back.
    param([Parameter(Mandatory = $true)][string]$Candidate, [Parameter(Mandatory = $true)][string]$ParentDispatchId)
    try {
        if ([IO.Path]::IsPathRooted($Candidate)) { return $Candidate }
        $normalized = $Candidate -replace '/', '\'
        if ($normalized -match '^OUTPUTS\\') {
            return Join-Path $TasksRoot (Join-Path $ParentDispatchId $normalized)
        }
        return Join-Path $AgentOSRoot $normalized
    } catch {
        return $null
    }
}

function Get-CandidateFilePaths {
    param([string]$Text)
    if (-not $Text) { return @() }
    # Bug found 2026-07-28 by Josh (crash reproduced even after the <>
    # guard): `[^`]` matches ANY character except a backtick, including
    # \r\n. A multi-line backtick-fenced command example in TASK.md prose
    # (e.g. a PowerShell one-liner shown across two lines) got captured as
    # ONE candidate spanning the newline, embedding a mid-string drive
    # letter/colon - which [IO.Path]::IsPathRooted rejects as "Illegal
    # characters in path". Restoring the classic "no newlines inside a
    # single backtick span" rule (`[^`\r\n]`) matches how backtick code
    # spans actually work in Markdown - they don't cross lines.
    return @(
        [regex]::Matches($Text, '`([^`\r\n]+)`') |
        ForEach-Object { $_.Groups[1].Value.Trim() } |
        Where-Object { Test-LooksLikeFilePath $_ }
    )
}

function Test-LooksReadOnlyTicket {
    # Added 2026-07-28 (Josh: operational-drift-triage's Scope section names
    # a dozen files it reads/inspects/might-call - `current_state.md`,
    # `scripts\write_escalation.ps1`, generic bare "TASK.md"/"RISK_RULES.md"
    # mentions with no real resolvable path - none of which it actually
    # changes. No amount of tightening the candidate-path regex fixes this
    # category of ticket, because the Scope text is legitimately describing
    # what the ticket READS, not what it changes. Detect the strong "this
    # ticket makes no file/git-state changes at all" signal up front and
    # skip the whole Scope-mining fallback rather than keep refining it.
    param([string]$ImpactScope, [string]$OutOfScopeText)
    $combined = "$ImpactScope`n$OutOfScopeText"
    $readOnlyPhrases = @(
        '唯讀分析', '不修改任何既有檔案', '不修改.{0,6}既有檔案內容',
        '不執行任何\s*`?git', 'read-only', 'read only'
    )
    foreach ($phrase in $readOnlyPhrases) {
        if ([regex]::IsMatch($combined, $phrase)) { return $true }
    }
    return $false
}

function Test-ExplicitlyForbiddenWholeFile {
    # Added 2026-07-28 (audit finding on escalation-fixture-classification):
    # the original exclusion rule was "path appears anywhere in the Out of
    # Scope section text => exclude", which wrongly dropped
    # data\escalations\ESCALATION_INDEX.jsonl because that ticket's Out of
    # Scope said "不得刪除 ESCALATION_INDEX.jsonl 的任何一筆" - a constraint
    # on *deleting entries from* the file, not a statement that the file is
    # off-limits to modify (it's explicitly an append-only target of the
    # ticket). Only exclude when a "don't touch/modify/rewrite this whole
    # file" verb sits immediately next to the path in the same clause.
    param([string]$OutOfScopeText, [string]$Candidate)
    if (-not $OutOfScopeText -or -not $Candidate) { return $false }
    $escaped = [regex]::Escape($Candidate)
    $verbs = "修改|觸碰|重寫|變更|動"
    $verbBeforePath = "(?:$verbs)[^\n。]{0,12}$escaped"
    $verbAfterPath = "$escaped[^\n。]{0,12}不[得可]?\s*(?:$verbs)"
    $englishBeforePath = "(?i)(?:do\s+not|don't|must\s+not|never)\s+(?:modify|touch|rewrite|change)[^\r\n.]{0,12}$escaped"
    $englishAfterPath = "(?i)$escaped[^\r\n.]{0,12}(?:must\s+not|may\s+not|cannot|can't)\s+be\s+(?:modified|touched|rewritten|changed)"
    return (
        [regex]::IsMatch($OutOfScopeText, $verbBeforePath) -or
        [regex]::IsMatch($OutOfScopeText, $verbAfterPath) -or
        [regex]::IsMatch($OutOfScopeText, $englishBeforePath) -or
        [regex]::IsMatch($OutOfScopeText, $englishAfterPath)
    )
}

function Get-PacketField {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Name
    )
    $escaped = [regex]::Escape($Name)
    $patterns = @(
        "(?im)^\s*$escaped\s*[:=]\s*(?<value>.+?)\s*$",
        "(?im)^\s*[-*]\s*$escaped\s*[:=]\s*(?<value>.+?)\s*$",
        "(?im)^\s*\*\*$escaped\*\*\s*[:=]\s*(?<value>.+?)\s*$"
    )
    foreach ($pattern in $patterns) {
        $match = [regex]::Match($Text, $pattern)
        if ($match.Success) {
            return $match.Groups["value"].Value.Trim().Trim('"').Trim("'")
        }
    }
    return ""
}

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $parent = Split-Path -Parent $Path
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Content, $Utf8NoBom)
}

function Invoke-GitProcess {
    param([Parameter(Mandatory = $true)][string]$Arguments)
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = "git"
    $psi.Arguments = $Arguments
    $psi.WorkingDirectory = $AgentOSRoot
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    # Fix (2026-07-28, found by Josh via Verify FAIL "docs\ARCHITECTURE.md
    # 有明顯亂碼"): without an explicit StandardOutputEncoding, .NET reads the
    # child process's stdout using the console's OEM/ANSI codepage, not
    # git's actual UTF-8 output. On a Traditional Chinese Windows host this
    # silently mangles any non-ASCII (including Chinese) diff content into
    # mojibake before the text ever reaches SCOPED_DIFF.patch. Forcing UTF8
    # here (no BOM) makes the captured text match what `git diff` actually
    # emitted.
    $psi.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
    $process = [System.Diagnostics.Process]::Start($psi)
    if ($null -eq $process) {
        return [pscustomobject]@{ ExitCode = -1; StdOut = ""; StdErr = "git_process_start_failed" }
    }
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()
    return [pscustomobject]@{ ExitCode = $process.ExitCode; StdOut = $stdout; StdErr = $stderr }
}

function Get-GitStatusCode {
    # Returns the 2-char porcelain status code for a path (e.g. "??" for
    # untracked, " M" for modified-not-staged), or "" if git status can't be
    # read for it.
    param([Parameter(Mandatory = $true)][string]$RelativePath)
    $gitRoot = $AgentOSRoot -replace '\\', '/'
    $safePath = '"' + ($RelativePath -replace '"', '\"') + '"'
    $result = Invoke-GitProcess -Arguments "-c safe.directory=$gitRoot status --porcelain -- $safePath"
    if ($result.ExitCode -ne 0 -or -not $result.StdOut) { return "" }
    # Bug found 2026-07-28 by Josh (root cause of every git_status=[] trace):
    # when `-split | Where-Object` produces exactly ONE match - the common
    # case here, since we pass a single pathspec - PowerShell's pipeline
    # unwraps a one-element result to a bare scalar string instead of a
    # 1-element array. The old code's trailing [0] then indexed into that
    # STRING's characters (returning just its first character, e.g. " "),
    # not the first line, and that 1-char value always failed the
    # `.Length -lt 2` check right below, so this function returned "" for
    # every single file regardless of its real status. Wrapping in @()
    # forces array context so [0] means "first line" again.
    $line = @($result.StdOut -split "`r?`n" | Where-Object { $_ })[0]
    if (-not $line -or $line.Length -lt 2) { return "" }
    return $line.Substring(0, 2)
}

function Invoke-GitDiffText {
    param([Parameter(Mandatory = $true)][string]$RelativePath, [string]$FullPath = "")
    $gitRoot = $AgentOSRoot -replace '\\', '/'
    $safePath = '"' + ($RelativePath -replace '"', '\"') + '"'

    # Fix (2026-07-28, found by Josh via Verify FAIL "SCOPED_DIFF.patch 未
    # 包含 snapshot writer 與 snapshot 檔案"): plain `git diff -- <path>`
    # only compares tracked content already known to git. A brand-new file
    # that hasn't been `git add`-ed yet is untracked, so git diff silently
    # returns nothing for it - exactly the case for a ticket whose main
    # deliverable IS a new script/doc file. Detect untracked status first
    # and, if so, embed the full current file content instead of an empty
    # diff, clearly labeled so Verify knows it's a new-file addition rather
    # than a real patch.
    $statusCode = Get-GitStatusCode -RelativePath $RelativePath
    if ($statusCode -eq "??") {
        $readPath = if ($FullPath) { $FullPath } else { Join-Path $AgentOSRoot ($RelativePath -replace '/', '\') }
        if (Test-Path -LiteralPath $readPath) {
            $content = Get-Content -Raw -LiteralPath $readPath -Encoding UTF8
            return "diff_status: new_untracked_file path=$RelativePath (full content shown below, git diff cannot represent an unstaged new file as a patch)`n--- /dev/null`n+++ $RelativePath`n$content`n"
        }
        return "diff_status: new_untracked_file_but_not_found path=$RelativePath`n"
    }

    $result = Invoke-GitProcess -Arguments "-c safe.directory=$gitRoot diff -- $safePath"
    $stdout = $result.StdOut
    $stderr = $result.StdErr
    $nonWarningStderr = @(
        $stderr -split "`r?`n" |
            Where-Object {
                $_ -and
                $_ -notmatch '^warning:' -and
                $_ -notmatch 'LF will be replaced by CRLF' -and
                $_ -notmatch 'CRLF will be replaced by LF'
            }
    )
    if ($result.ExitCode -ne 0 -and $nonWarningStderr.Count -gt 0) {
        return "diff_status: git_diff_failed path=$RelativePath exit_code=$($result.ExitCode)`n$($nonWarningStderr -join [Environment]::NewLine)`n"
    }
    if ($nonWarningStderr.Count -gt 0) {
        return "$stdout`ndiff_stderr:`n$($nonWarningStderr -join [Environment]::NewLine)`n"
    }
    return $stdout
}

function Find-ExistingVerifyDispatch {
    param([string]$ParentDispatchId)
    foreach ($task in Get-ChildItem -LiteralPath $TasksRoot -Filter "TASK.md" -File -Recurse -ErrorAction SilentlyContinue) {
        $text = Get-Content -Raw -LiteralPath $task.FullName -Encoding UTF8
        if ((Get-PacketField $text "parent_dispatch_id") -eq $ParentDispatchId -and
            (Get-PacketField $text "type") -eq "CODEX_VERIFY") {
            return $task.Directory.Name
        }
    }
    return ""
}

function New-CodexVerifyTask {
    param([string]$ParentDispatchId, [string]$GovernanceVersion, [string]$GovernanceHash, [switch]$Force)
    $existing = Find-ExistingVerifyDispatch -ParentDispatchId $ParentDispatchId
    if ($existing -and -not $Force) {
        Write-Output "verify_task_status=already_exists"
        Write-Output "verify_dispatch_id=$existing"
        return $existing
    }
    if ($existing -and $Force) {
        # Archive the existing (presumably FAILED, bad-bundle) verify child's
        # outputs before we overwrite anything, so the prior verdict/evidence
        # is never silently lost - matches the ATTEMPTS\ convention used
        # elsewhere in AgentOS for superseded attempts.
        $existingOutputDir = Join-Path $TasksRoot (Join-Path $existing "OUTPUTS")
        $existingResultPath = Join-Path $existingOutputDir "RESULT.md"
        $existingTestPath = Join-Path $existingOutputDir "TEST_RESULT.md"
        if ((Test-Path -LiteralPath $existingResultPath) -or (Test-Path -LiteralPath $existingTestPath)) {
            $stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $attemptsDir = Join-Path $existingOutputDir "ATTEMPTS\$stamp"
            New-Item -ItemType Directory -Force -Path $attemptsDir | Out-Null
            foreach ($p in @($existingResultPath, $existingTestPath)) {
                if (Test-Path -LiteralPath $p) {
                    # Move (not copy - Josh caught this 2026-07-28): the queue
                    # runner's $ready filter only re-admits a task when either
                    # RESULT.md is absent, or task_status is retrying/
                    # fallback_ready. The child TASK.md template below always
                    # writes task_status: ready, so a left-behind RESULT.md
                    # from a Copy-Item would silently block re-dispatch
                    # (tasks_executed=0, reason=no_ready_tasks) even though
                    # verify_task_status printed "created". Moving the file
                    # out satisfies the "RESULT.md absent" branch instead.
                    Move-Item -LiteralPath $p -Destination (Join-Path $attemptsDir (Split-Path -Leaf $p)) -Force
                }
            }
            Write-Output "verify_prior_attempt_archived=$attemptsDir"
        }
    }

    $parentTaskPath = Join-Path $TasksRoot (Join-Path $ParentDispatchId "TASK.md")
    $parentResultPath = Join-Path $TasksRoot (Join-Path $ParentDispatchId "OUTPUTS\RESULT.md")
    if (-not (Test-Path -LiteralPath $parentResultPath)) {
        throw "parent RESULT.md not found: $parentResultPath (ticket has not completed yet)"
    }
    $parentResult = Get-Content -Raw -LiteralPath $parentResultPath -Encoding UTF8

    # NEW (2026-07-28, found on queue-active-index-optimization's revision-1/
    # revision-2 Verify FAILs): task_queue_runner.ps1's New-RevisionTask always
    # writes a minimal "Claude Revision Round N" TASK.md whose impact_scope is
    # a generic "core_script" string, has no "## Scope" section at all, and
    # references the original ticket/prior-verify paths as PLAIN prose lines
    # (not backtick-quoted) - so none of the extraction above ever sees them.
    # Both revision Verify sessions correctly complained they couldn't reach
    # the original acceptance criteria or prior evidence at all. Detect
    # revision_of: here and make sure the original ticket's TASK.md and its
    # own OUTPUTS dir are explicitly reachable from this bundle regardless of
    # what the revision's own Scope text does or doesn't mention.
    $originalContextPaths = @()
    if (Test-Path -LiteralPath $parentTaskPath) {
        $parentTaskTextForRevisionCheck = Get-Content -Raw -LiteralPath $parentTaskPath -Encoding UTF8
        $revisionOf = Get-PacketField $parentTaskTextForRevisionCheck "revision_of"
        if ($revisionOf) {
            $originalTaskPathForContext = Join-Path $TasksRoot (Join-Path $revisionOf "TASK.md")
            $originalResultPathForContext = Join-Path $TasksRoot (Join-Path $revisionOf "OUTPUTS\RESULT.md")
            if (Test-Path -LiteralPath $originalTaskPathForContext) { $originalContextPaths += $originalTaskPathForContext }
            if (Test-Path -LiteralPath $originalResultPathForContext) { $originalContextPaths += $originalResultPathForContext }
            # Added 2026-07-28 (Josh's finding on operational-drift-triage-
            # revision-1): the original ticket's real gate/test evidence lives
            # in TEST_RESULT.full.md (the pre-overwrite backup made when this
            # script first ran against the original ticket), not in its
            # RESULT.md. Without this, a content-only revision's bundle only
            # points the verifier at the original's TASK.md/RESULT.md and the
            # revision's own (often missing) TEST_RESULT.md - the verifier
            # never sees the raw gate output the corrected table must be
            # sourced from. Prefer TEST_RESULT.full.md; fall back to
            # TEST_RESULT.md if no backup was ever made (e.g. original never
            # had a richer TEST_RESULT to begin with).
            $originalTestFullPathForContext = Join-Path $TasksRoot (Join-Path $revisionOf "OUTPUTS\TEST_RESULT.full.md")
            $originalTestPathForContext = Join-Path $TasksRoot (Join-Path $revisionOf "OUTPUTS\TEST_RESULT.md")
            if (Test-Path -LiteralPath $originalTestFullPathForContext) {
                $originalContextPaths += $originalTestFullPathForContext
            } elseif (Test-Path -LiteralPath $originalTestPathForContext) {
                $originalContextPaths += $originalTestPathForContext
            }
            Write-Output "revision_of_detected=$revisionOf original_context_paths=$($originalContextPaths.Count)"
        }
    }
    $changedFiles = @(
        [regex]::Matches($parentResult, '(?mi)^changed_file\s*:\s*(.+)$') |
        ForEach-Object { $_.Groups[1].Value.Trim() } |
        Where-Object { $_ }
    )
    $changedFileSource = "result_md_changed_file_lines"

    if (-not $changedFiles.Count) {
        # NEW (2026-07-28, per Josh's audit): try the canonical Evidence and
        # Reporting Contract fields (docs\EVIDENCE_AND_REPORTING_CONTRACT.md
        # Section 3 - required since 2026-06-24) before falling further back
        # to mining TASK.md prose. files_modified:/files_created: are the
        # actual governance-mandated field names; changed_file: (checked
        # above) is a narrower ad hoc convention only ~6 tickets happen to
        # use. Both are explicit structured author intent - unlike guessing
        # from Scope-section prose, which the audit showed produces both
        # false negatives and false positives (API endpoints, directories,
        # wildcards, example filenames mistaken for real changed files).
        $placeholderValues = @("not_applicable", "unknown", "none", "n/a")
        $evidenceListCandidates = @()
        foreach ($fieldName in @("files_modified", "files_created")) {
            $fieldMatch = [regex]::Match($parentResult, "(?mi)^$fieldName\s*:\s*(.*)$")
            if ($fieldMatch.Success) {
                $rawValue = $fieldMatch.Groups[1].Value.Trim()
                if ($rawValue -and ($placeholderValues -notcontains $rawValue.ToLowerInvariant())) {
                    $evidenceListCandidates += @(
                        $rawValue -split '[,;]' | ForEach-Object { $_.Trim().Trim('`').Trim() } | Where-Object { $_ }
                    )
                }
            }
        }
        $evidenceListCandidates = @($evidenceListCandidates | Where-Object { Test-LooksLikeFilePath $_ } | Select-Object -Unique)
        if ($evidenceListCandidates.Count) {
            $changedFiles = $evidenceListCandidates
            $changedFileSource = "result_md_files_modified_created_fields"
        }
    }

    if (-not $changedFiles.Count) {
        # Fallback (added 2026-07-27, widened 2026-07-28 per Josh's finding):
        # some Codex plan-mode RESULT.md deliveries use a free-form "AgentOS
        # Dispatch Result" narrative instead of the codex_build.md
        # changed_file: contract, so there is nothing to scrape from
        # RESULT.md. The parent TASK.md's impact_scope: frontmatter line is
        # tried first, but for docs-governance-status-autolink that line was
        # only prose ("新增小型自動產生 status 文件的腳本") - it never named
        # scripts\write_governance_status_snapshot.ps1 or
        # docs\GOVERNANCE_STATUS_SNAPSHOT.md. Those exact paths only appear
        # inside the numbered "## Scope" section body. So: try impact_scope
        # first, and if that alone doesn't name any concrete new/changed
        # files, widen to the whole "## Scope" section text. Anything also
        # named in "## Out of Scope" (e.g. AGENTS.md, a read-only helper
        # script the ticket calls but must not modify) is excluded, since
        # those are explicitly NOT changed files.
        if (Test-Path -LiteralPath $parentTaskPath) {
            $parentTaskTextForScope = Get-Content -Raw -LiteralPath $parentTaskPath -Encoding UTF8
            $scopeLine = Get-PacketField $parentTaskTextForScope "impact_scope"
            $outOfScopeMatchForReadOnlyCheck = [regex]::Match($parentTaskTextForScope, '(?ms)^##\s*Out of Scope.*?$(.*?)(?=^##\s|\z)')
            $outOfScopeTextForReadOnlyCheck = if ($outOfScopeMatchForReadOnlyCheck.Success) { $outOfScopeMatchForReadOnlyCheck.Groups[1].Value } else { "" }
            if (Test-LooksReadOnlyTicket -ImpactScope $scopeLine -OutOfScopeText $outOfScopeTextForReadOnlyCheck) {
                Write-Output "read_only_ticket_detected=true (skipping Scope-section file mining entirely)"
                $changedFiles = @()
                $changedFileSource = "read_only_ticket_no_scope_mining"
            } else {
            $candidates = @(Get-CandidateFilePaths $scopeLine)
            $source = "task_md_impact_scope_fallback"

            $scopeSectionMatch = [regex]::Match($parentTaskTextForScope, '(?ms)^##\s*Scope\s*$(.*?)(?=^##\s|\z)')
            if ($scopeSectionMatch.Success) {
                $scopeSectionCandidates = @(Get-CandidateFilePaths $scopeSectionMatch.Groups[1].Value)
                if ($scopeSectionCandidates.Count) {
                    $candidates = @($candidates + $scopeSectionCandidates) | Select-Object -Unique
                    $source = "task_md_scope_section_fallback"
                }
            }

            $outOfScopeMatch = [regex]::Match($parentTaskTextForScope, '(?ms)^##\s*Out of Scope.*?$(.*?)(?=^##\s|\z)')
            $outOfScopeText = if ($outOfScopeMatch.Success) { $outOfScopeMatch.Groups[1].Value } else { "" }
            $candidates = @(
                $candidates | Where-Object { -not (Test-ExplicitlyForbiddenWholeFile -OutOfScopeText $outOfScopeText -Candidate $_) }
            )

            # Filter (2026-07-28, audit finding on operational-drift-triage):
            # a read-only analysis ticket's Scope text often only names its
            # own OUTPUTS\ directory (where RESULT.md/TEST_RESULT.md already
            # live) rather than any real source file it changed. That path is
            # already covered separately as "## Delivery Artifact" in the
            # bundle below - counting it again as a "changed file" wrongly
            # forces change_required to true for a ticket that made no real
            # source change.
            # Narrowed 2026-07-28 (see Resolve-CandidatePath): only exclude
            # the bundle's OWN meta-files (already linked elsewhere in the
            # bundle template below), not every file under this ticket's
            # OUTPUTS\ folder - a real deliverable like BENCHMARK_RESULT.json
            # living in OUTPUTS\ is legitimate evidence and must NOT be
            # filtered out just because of where it happens to live.
            # Only exclude pipeline-generated transport/control artifacts.
            # RESULT.md and TEST_RESULT*.md are agent-authored evidence and
            # must remain in scope when the manifest explicitly names them.
            $selfMetaFiles = @(
                "AGENT_OUTPUT.md",
                "HEARTBEAT.json",
                "VERIFY_BUNDLE.md",
                "GIT_VERIFIED_CHANGES.json",
                "SCOPED_DIFF.patch"
            )
            $candidates = @(
                $candidates | Where-Object {
                    $resolved = Resolve-CandidatePath -Candidate $_ -ParentDispatchId $ParentDispatchId
                    # Resolve-CandidatePath now fails closed (returns $null)
                    # instead of throwing - drop anything it couldn't resolve
                    # rather than crash on Split-Path/-like against $null.
                    if (-not $resolved) { return $false }
                    $leaf = Split-Path -Leaf $resolved
                    $isSelfOutputsDir = $resolved.TrimEnd('\') -eq (Join-Path $TasksRoot (Join-Path $ParentDispatchId "OUTPUTS")).TrimEnd('\')
                    -not $isSelfOutputsDir -and -not ($selfMetaFiles -contains $leaf -and $resolved -like "*\$ParentDispatchId\OUTPUTS\*")
                }
            )

            $changedFiles = $candidates
            if ($changedFiles.Count) { $changedFileSource = $source }
            }
        }
    }
    $changeRequiredMatch = [regex]::Match(
        $parentResult,
        '(?mi)^[\s>*_-]*change_required\s*[:\uFF1A]\s*\*{0,2}(true|false)\b'
    )
    $changeRequired = if ($changeRequiredMatch.Success) {
        $changeRequiredMatch.Groups[1].Value.ToLowerInvariant()
    } elseif ($changedFiles.Count -gt 0) {
        # No explicit field, but we do have concrete changed files (from
        # either source above) - "unknown" would incorrectly let the verify
        # bundle's query-type exemption kick in. Real files means real change.
        "true"
    } else {
        # No explicit field AND no concrete changed files found by any
        # fallback (2026-07-28: changed from "unknown" to "false" - the
        # child prompt's query-type exemption only triggers on an explicit
        # "false", so a read-only/analysis-only ticket with genuinely no
        # changed files needs this to be "false", not an ambiguous
        # "unknown" that silently behaves like "true" and demands a diff
        # that will never exist).
        "false"
    }

    # Added 2026-07-28 (structural redesign Pillar B, per Josh's direction:
    # docs\VERIFY_PIPELINE_STRUCTURAL_REDESIGN_2026-07-28.md). Everything
    # above this point still guesses change_required/changed_files from the
    # agent's own free-text self-report - exactly the mechanism that produced
    # every "agent said X, bundle said Y" FAIL this session (dashboard-plane-
    # naming-consistency-revision-1, operational-drift-triage-revision-1,
    # both revision-2 attempts). dispatch_task_packet.ps1 now independently
    # snapshots git status before/after the agent runs and writes
    # GIT_VERIFIED_CHANGES.json - ground truth, not self-report. Surface it
    # in the bundle so the verifier can see it directly, and raise a loud,
    # high-confidence flag on the one disagreement pattern that's actually
    # bitten us repeatedly: the self-report and ground truth disagreeing on
    # whether ANY change happened at all. Deliberately not doing per-path
    # set comparison here (real changed-file lists legitimately differ in
    # scope/wording from a raw git status line) - that finer-grained check
    # is future work, not something to invent under time pressure now.
    $gitVerifiedChangesPath = Join-Path (Split-Path -Parent $parentResultPath) "GIT_VERIFIED_CHANGES.json"
    $gitVerifiedSummary = "git_verified_snapshot: not_found (ticket predates Pillar B, or dispatch_task_packet.ps1 snapshot failed)"
    $evidenceManifestMismatch = $false
    if (Test-Path -LiteralPath $gitVerifiedChangesPath) {
        try {
            $gitVerified = Get-Content -Raw -LiteralPath $gitVerifiedChangesPath -Encoding UTF8 | ConvertFrom-Json
            if ($gitVerified.snapshot_status -eq "captured") {
                $gitTotalChanges = @($gitVerified.git_verified_files_modified).Count +
                    @($gitVerified.git_verified_files_created).Count +
                    @($gitVerified.git_verified_files_deleted).Count
                $gitVerifiedSummary = "git_verified_snapshot: captured; modified=$(@($gitVerified.git_verified_files_modified).Count) created=$(@($gitVerified.git_verified_files_created).Count) deleted=$(@($gitVerified.git_verified_files_deleted).Count)"
                $selfReportedAnyChange = ($changeRequired -eq "true")
                $gitVerifiedAnyChange = ($gitTotalChanges -gt 0)
                if ($selfReportedAnyChange -ne $gitVerifiedAnyChange) {
                    $evidenceManifestMismatch = $true
                    $gitVerifiedSummary += " | MISMATCH: self-reported change_required=$changeRequired but independent git snapshot shows $(if ($gitVerifiedAnyChange) { 'real changes' } else { 'zero changes' })"
                }
            } else {
                $gitVerifiedSummary = "git_verified_snapshot: unavailable (before_reason=$($gitVerified.before_reason); after_reason=$($gitVerified.after_reason))"
            }
        } catch {
            $gitVerifiedSummary = "git_verified_snapshot: unreadable ($($_.Exception.Message))"
        }
    }
    $parentOutputDir = Split-Path -Parent $parentResultPath
    $diffPath = Join-Path $parentOutputDir "SCOPED_DIFF.patch"
    $testPath = Join-Path $parentOutputDir "TEST_RESULT.md"
    $bundlePath = Join-Path $parentOutputDir "VERIFY_BUNDLE.md"

    # Safety addition (not in the original function): preserve the Builder's
    # real TEST_RESULT.md before it gets overwritten below.
    $backupPath = Join-Path $parentOutputDir "TEST_RESULT.full.md"
    if (Test-Path -LiteralPath $testPath) {
        if (-not (Test-Path -LiteralPath $backupPath)) {
            Copy-Item -LiteralPath $testPath -Destination $backupPath
            Write-Output "test_result_backup=$backupPath"
        } else {
            # A later Builder/revision may legitimately replace TEST_RESULT.md
            # after the first bundle created TEST_RESULT.full.md. Reusing the
            # older backup would silently roll the evidence back (observed in
            # antigravity round 2: 7 cases reverted to 6). Refresh only when
            # the current file is newer and its bytes actually differ; this
            # avoids treating our own fallback rewrite as new evidence.
            $testItem = Get-Item -LiteralPath $testPath
            $backupItem = Get-Item -LiteralPath $backupPath
            $testHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $testPath).Hash
            $backupHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backupPath).Hash
            if ($testItem.LastWriteTimeUtc -gt $backupItem.LastWriteTimeUtc -and $testHash -ne $backupHash) {
                Copy-Item -Force -LiteralPath $testPath -Destination $backupPath
                Write-Output "test_result_backup_refreshed=$backupPath"
            }
        }
    }

    # The 2026-07-28 debugging saga (untracked-file miss -> git status
    # scalar/array bug) is resolved and covered by comments at the functions
    # themselves; this loop stays lean but (a) still emits one summary trace
    # line per candidate for future debugging, and (b) wraps each candidate
    # in try/catch so one malformed entry (e.g. a TASK.md prose template
    # like `data\codex_tasks\<dispatch_id>\` that isn't a real path - crash
    # found on operational-drift-triage 2026-07-28) can never abort the
    # whole bundle; it just gets skipped with a diagnostic note instead.
    $diffText = ""
    foreach ($changedFile in $changedFiles) {
        try {
            $candidate = Resolve-CandidatePath -Candidate $changedFile -ParentDispatchId $ParentDispatchId
            if (-not $candidate) {
                Write-Output "diff_trace: changed_file=[$changedFile] skipped=unresolvable_path"
                continue
            }
            if (-not $candidate.StartsWith($AgentOSRoot, [StringComparison]::OrdinalIgnoreCase)) {
                Write-Output "diff_trace: changed_file=[$changedFile] skipped=outside_agentos_root"
                continue
            }
            $relative = $candidate.Substring($AgentOSRoot.Length).TrimStart('\')
            $leaf = Split-Path -Leaf $candidate
            $parentTaskArtifact = Join-Path $TasksRoot (Join-Path $ParentDispatchId "TASK.md")
            $parentOutputsArtifactDir = Join-Path $TasksRoot (Join-Path $ParentDispatchId "OUTPUTS")
            $pipelineMetaFiles = @(
                "AGENT_OUTPUT.md",
                "HEARTBEAT.json",
                "VERIFY_BUNDLE.md",
                "GIT_VERIFIED_CHANGES.json",
                "SCOPED_DIFF.patch"
            )
            $isParentTaskArtifact = $candidate.Equals($parentTaskArtifact, [StringComparison]::OrdinalIgnoreCase)
            $isParentOutputMeta = $pipelineMetaFiles -contains $leaf -and
                $candidate.StartsWith($parentOutputsArtifactDir + "\", [StringComparison]::OrdinalIgnoreCase)
            if ($isParentTaskArtifact -or $isParentOutputMeta) {
                Write-Output "diff_trace: changed_file=[$changedFile] skipped=pipeline_transport_or_control_artifact"
                continue
            }
            if (Test-Path -LiteralPath $candidate -PathType Container) {
                # Guard (2026-07-28, audit finding on dashboard-plane-naming-
                # consistency: a Scope-section candidate resolved to a whole
                # directory, e.g. `dashboard\frontend`). Diffing an entire
                # directory via `git diff -- <dir>` pulls in every uncommitted
                # change anywhere under it - the same scope-creep problem
                # flagged for queue-active-index-optimization. Note it
                # explicitly instead of silently vacuuming in unrelated
                # changes.
                Write-Output "diff_trace: changed_file=[$changedFile] candidate=[$candidate] directory"
                $diffText += "diff_status: directory_not_individually_diffed path=$relative (candidate resolved to a directory; list specific files in impact_scope/Scope instead)`n"
                continue
            }
            $statusForTrace = Get-GitStatusCode -RelativePath $relative
            Write-Output "diff_trace: changed_file=[$changedFile] candidate=[$candidate] git_status=[$statusForTrace]"
            $diffText += Invoke-GitDiffText -RelativePath $relative -FullPath $candidate
        } catch {
            Write-Output "diff_trace: changed_file=[$changedFile] error=[$($_.Exception.Message)]"
            $diffText += "diff_status: candidate_processing_failed changed_file=$changedFile error=$($_.Exception.Message)`n"
        }
    }
    if (-not $diffText) { $diffText = "diff_status: missing_or_empty" }
    Write-Utf8File -Path $diffPath -Content $diffText

    $testEvidence = @(
        [regex]::Matches($parentResult, '(?mi)^[\s>*_-]*\*{0,2}(test_command|test_result|verification|evidence)\*{0,2}\s*[:\uFF1A]\s*(.+)$') |
        ForEach-Object { $_.Value.Trim() }
    )
    if ($testEvidence.Count) {
        Write-Utf8File -Path $testPath -Content ($testEvidence -join [Environment]::NewLine)
    } elseif (Test-Path -LiteralPath $backupPath) {
        # Fallback (added 2026-07-27): the RESULT.md-scrape above found no
        # test_command/test_result/verification/evidence lines - this is
        # expected for the "AgentOS Dispatch Result" narrative format, which
        # documents tests in prose rather than in those exact fields. Do NOT
        # collapse this to a "test_status: missing" placeholder when a real,
        # richer TEST_RESULT.full.md backup exists; reuse its full content so
        # the Verify session actually sees the real evidence.
        $fullContent = Get-Content -Raw -LiteralPath $backupPath -Encoding UTF8
        Write-Utf8File -Path $testPath -Content $fullContent
        Write-Output "test_result_source=test_result_full_md_fallback"
    } else {
        Write-Utf8File -Path $testPath -Content "test_status: missing"
    }

    $originalContextSection = if ($originalContextPaths.Count) {
        @"

## Original Ticket Context (this is a revision)

This ticket is a revision of $revisionOf. Its own acceptance criteria are
inherited from that original ticket, not restated here. Read these paths to
find the real acceptance criteria and what the prior Verify attempt actually
flagged:

$($originalContextPaths -join [Environment]::NewLine)
"@
    } else { "" }
    $acceptanceCriteriaNote = if ($originalContextPaths.Count) {
        "Use the acceptance criteria and boundaries from the ORIGINAL ticket listed under `"Original Ticket Context`" above, not from this revision's own TASK.md (which only restates the fix request)."
    } else {
        "Use only the acceptance criteria and boundaries in the parent task ticket."
    }
    $allowedPaths = @($changedFiles + $originalContextPaths) | Select-Object -Unique
    $bundle = @"
# Codex Blind Verify Bundle

parent_dispatch_id: $ParentDispatchId
workflow_version: 1.2
plan_reasoning_included: false
prior_chat_history_included: false
change_required: $changeRequired
changed_file_source: $changedFileSource
$gitVerifiedSummary
evidence_manifest_mismatch: $($evidenceManifestMismatch.ToString().ToLowerInvariant())

## Task Ticket

$parentTaskPath

## Acceptance Criteria

$acceptanceCriteriaNote
$originalContextSection
## Scoped Diff

$diffPath

## Test Result

$testPath

## Delivery Artifact

$parentResultPath

## Allowed Workspace Paths

$($allowedPaths -join [Environment]::NewLine)
"@
    Write-Utf8File -Path $bundlePath -Content $bundle

    $childId = "$ParentDispatchId-codex-verify"
    $childPath = Join-Path $TasksRoot (Join-Path $childId "TASK.md")
    $child = @"
# Task Packet: Codex Blind Verify

dispatch_id: $childId
parent_dispatch_id: $ParentDispatchId
type: CODEX_VERIFY
assigned_to: Codex
route_to: Codex
codex_mode: verify
workflow_version: 1.2
impact_scope: internal_only
dispatch_status: ready_to_route
requires_josh_approval: false
approval: inherited_verify_of_approved_parent
task_status: ready
governance_version: $GovernanceVersion
governance_hash: $GovernanceHash

## Blind Verify Input

Read only this verify bundle and the paths explicitly listed inside it:
$bundlePath

This is a new independent verification session. Do not use plan reasoning or
prior chat history. Use read-only inspection and acceptance criteria only.
If test result or delivery evidence is missing, do not PASS. Missing scoped
diff cannot PASS unless the bundle explicitly says ``change_required: false``.

Query-type rule: when the bundle says ``change_required: false`` AND lists no
changed files, the task is a query-type delivery. In that case at least one
``evidence:`` line in the test result is sufficient verification evidence; you
must not FAIL solely because the scoped diff is empty or because
test_command/test_result lines are absent. This rule applies only when both
conditions hold; any changed file re-enables the full test evidence
requirement.

Ground-truth rule: the bundle header's `git_verified_snapshot` line and
`evidence_manifest_mismatch` flag come from an independent git status
snapshot taken by the dispatcher itself, not from the agent's own report.
If `evidence_manifest_mismatch: true`, treat this as a hard FAIL signal
regardless of how convincing the delivery artifact's narrative is - it means
what the agent claimed and what the system independently observed on disk
disagree on whether any change happened at all.

Your response must include exactly one machine-readable verdict line:
verify_verdict: PASS
or
verify_verdict: FAIL
or
verify_verdict: NEEDS_HUMAN_DECISION

Then include findings, evidence, and required changes in Traditional Chinese.
"@
    Write-Utf8File -Path $childPath -Content $child
    Write-Output "verify_task_status=created"
    Write-Output "verify_dispatch_id=$childId"
    Write-Output "verify_task_path=$childPath"
    return $childId
}

$parentTaskPath = Join-Path $TasksRoot (Join-Path $ParentDispatchId "TASK.md")
if (-not (Test-Path -LiteralPath $parentTaskPath)) {
    throw "Parent TASK.md not found: $parentTaskPath"
}
$parentTaskText = Get-Content -Raw -LiteralPath $parentTaskPath -Encoding UTF8
$governanceVersion = Get-PacketField $parentTaskText "governance_version"
$governanceHash = Get-PacketField $parentTaskText "governance_hash"
if (-not $governanceVersion -or -not $governanceHash) {
    throw "Parent TASK.md missing governance_version/governance_hash"
}

# Bug found 2026-07-28 (Josh: "腳本最後把整個函式輸出丟棄"): this used to end
# in `| Out-Null`, which silently discarded every Write-Output line the
# function emits - not just its `return $childId` value, but also
# verify_task_status=/verify_dispatch_id=/test_result_backup=/
# changed_file_source=/diff_trace= progress lines. dispatch_task_packet.ps1's
# call site parses those lines from this script's stdout, and a human running
# it interactively needs to see them too. Let the function's own output
# stream flow straight through instead of capturing or discarding it.
New-CodexVerifyTask -ParentDispatchId $ParentDispatchId `
    -GovernanceVersion $governanceVersion -GovernanceHash $governanceHash -Force:$Force
