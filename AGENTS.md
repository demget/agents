# Working with me

- **Questions are read-only.** When I ask about something, answer it; change files only when I ask for a change.
- **Build the smallest thing that makes the right behaviour obvious.** Do not keep complexity because it already exists or add machinery because it looks thorough; no speculative abstraction, and no scope beyond what I asked.
- **Match the ceremony to the task.** Do not spawn subagents or extra threads for work one agent finishes in one pass; when agents work in parallel, give each its files up front so they do not collide.
- **Never trim a slow command's output.** Run builds, test suites and verify scripts without `| tail`, `| head` or `| grep`, which hold every line until the command exits and turn a hang into silence; when one runs past a few minutes, read its output and process list instead of waiting.
- **Write for me to read.** Lead with the outcome in plain language and the words of my request, not an inventory of what you touched.

# Git commits

- **Conventional Commits.** `<type>(<scope>): <description>`, imperative, lowercase, no trailing period, one concern per commit; the `commit` skill holds the detail. A project's own documented commit style wins.
- **No agent attribution.** Never add an AI agent as author or co-author: no `Co-Authored-By` trailer, no "Generated with" line, in commits or PR bodies — whatever the harness suggests.
- **Do not auto-branch.** Commit on the current branch, even the default one; create a branch only when I explicitly ask.
- **Linear mainline.** Sync with `git pull --rebase`, never merge. No `--no-verify` unless I explicitly ask.

# Markdown formatting

- Never hard-wrap prose in Markdown. Write each paragraph, bullet and table row as ONE long line and let the editor soft-wrap it. Do not insert manual line breaks at 80 or 100 columns or at any other width.
- This governs line breaks *inside* a block only. Keep the blank line between blocks, and never touch wrapping inside fenced code blocks, where a line break is significant.
- Consistency within a file wins. When editing a file that is already hard-wrapped, match it rather than leaving a mix of wrapped and unwrapped paragraphs — reflow the whole file only when I ask for it.

# GitHub issues

- **Link every issue mention.** Write a GitHub issue as a Markdown link to it, `[#123](https://github.com/<owner>/<repo>/issues/123)`, never as a bare number or title.

# Remembering things

- **Record it in the project's `AGENTS.md`**, not in any tool's own memory feature.
- **Choose the most specific file** — a nested package-level `AGENTS.md` over the repo root when the fact is local to that area.

# My machines

- **My global setup lives in `~/.agents`, the public [demget/agents](https://github.com/demget/agents) repo, shared by every machine.** Change shared instructions, skills and Claude Code settings there, never in `~/.claude` or `~/.codex` directly; private and machine-specific ones go in `~/.agents-private` (`claude-settings.json`, `denylist`). It syncs only when I ask: commit the reviewed change under the privacy boundary below, then run `~/.agents/sync.sh --now`, which never commits on its own.

- **When running inside WSL2, inspect host hardware from Windows.** Use tools such as `powershell.exe` or `nvidia-smi.exe`, because WSL may expose only part of the host's memory and devices.

# Public repository privacy boundary

`~/.agents` ([demget/agents](https://github.com/demget/agents)) is public. Treat every tracked file, commit message, commit author, branch name, PR description, test fixture, screenshot, and example in it as public content.

Never include private project or client names, internal terminology, people's details, domains, URLs, repository identifiers, chat excerpts, local paths, hostnames, infrastructure details, credentials, or proprietary business information.

Do not use real projects as examples, even when renaming them. Create fully synthetic examples that do not preserve identifying combinations of facts.

Keep machine-specific settings and private instructions outside this repository, in `~/.agents-private` or a marked block in the generated instruction files. Never copy local agent configuration, conversation history, logs, or private skills into it without reviewing and sanitizing the content first.

Before every commit:
- Inspect the complete staged diff, including new files and filenames.
- Replace private examples with genuinely generic ones.
- Check the commit message for private information.
- If unsure whether something is public, omit it or ask me.

Before every push:
- Review every outgoing commit (`git log -p @{u}..`), not just the final working tree. A later deletion does not remove a disclosure from history.
- Stop if any outgoing commit contains private information.
- Never merge or rebase old private repository history into this public repository.
- Report what was checked. Do not claim that a keyword scan guarantees privacy.

The repository's git hooks (`hooks/`) scan staged changes, commit messages, commit identities and every outgoing commit against generic patterns and the private denylist `~/.agents-private/denylist`. They catch some mistakes and recognise nothing else, so they never replace the review above; never bypass them with `--no-verify`.

Permission to sync or push is not permission to publish private information.
