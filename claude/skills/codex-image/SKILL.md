---
name: codex-image
description: Generate images with the local Codex CLI (OpenAI gpt-image-2 via the image_gen tool), and run any other one-shot `codex exec` task from the shell without it hanging. Use for still image assets (product shots, prize objects, UI art, mascots, backgrounds) when the user asks for codex or gpt-image-2, when a generation needs local reference images attached, or when other generators (grok, Higgsfield) are unavailable or out of credits. Also use whenever you are about to call `codex exec` for anything, such as asking Codex to write, translate or review text. Triggers on "codex image", "gpt-image-2", "generate with codex", "ask codex", "use codex for this".
---

# codex-image

The local `codex` binary (OpenAI Codex CLI) carries an `image_gen.imagegen` tool backed by gpt-image-2. Drive it single-turn from the shell — no interactive UI. Verify it is there with `printf '%s' "List the tools you have available, names only." | codex exec --sandbox read-only -` if in doubt.

## Never let `codex exec` hang

**Every `codex exec` call gets a stdin that ends: pipe the prompt in and end the arguments with `-`.** Given a prompt argument, `codex exec` still reads stdin whenever stdin is not a terminal, to append it as a `<stdin>` block. An agent's shell hands it an open pipe that never closes, so the run prints `Reading additional input from stdin...` and waits until the Bash timeout kills it (exit 137), with no output.

```bash
printf '%s' "<PROMPT>" | codex exec --sandbox read-only -                    # short prompt
codex exec --sandbox read-only -o /tmp/answer.md - < /tmp/prompt.md          # long prompt from a file
```

- A long or multilingual prompt goes in a file and in through `< file`, never through `"$(cat file)"` as an argument.
- `-o <FILE>` writes Codex's final message alone to a file; read the answer there rather than parsing the progress log on stdout.
- If a prompt argument is unavoidable, close stdin explicitly: `codex exec … "<PROMPT>" </dev/null`.
- Outside a git repository add `--skip-git-repo-check`; a text-only task takes `--sandbox read-only`.

## The one-shot recipe

```bash
cd <ASSETS_DIR> && printf '%s' "<PROMPT>. Using your image_gen tool, generate the image and save it as <NAME>.png in the current directory, then reply with only the absolute path of the saved file." | codex exec --sandbox workspace-write -i /abs/ref1.webp -i /abs/ref2.webp - 2>&1 | tail -2
```

- **Prompt via stdin (`-`), never as an argument after `-i`.** The `-i <FILE>...` flag is variadic and swallows a trailing prompt argument as another file path; the run then dies with "No prompt provided via stdin". Piping with `printf '%s' "…" | codex exec … -` sidesteps it entirely.
- **`--sandbox workspace-write`, not `--full-auto`.** The write sandbox is enough for image_gen to save into the cwd, and auto-approve flags are what permission classifiers reject. `cd` into the assets dir first — the sandbox writes only under the cwd.
- **`-i` attaches local reference images** (repeat per file; webp/png/jpg all work). gpt-image-2 follows an attached style register far better than a described one, so pass the real assets the new image must sit beside.
- **End the prompt with the save-and-reply-path instruction** shown above; the last stdout line is then the absolute path, easy to verify.
- Bash timeout: generous, up to ~300000 ms; a generation runs ~60-120 s. Cost lands on the Codex account's usage.

## Tips

- **No transparency.** gpt-image-2 will not hand back a usable alpha channel through this path; generate on a pure flat black (or the destination's exact color) background and alpha-cut afterwards (fal `birefnet`, Higgsfield `remove_background`, or a local matting tool).
- **Aspect:** state it in words ("square 1:1", "portrait 3:4"); the tool picks the nearest supported size.
- **One object per call.** Batch by looping the recipe with different prompts/names, not by asking for a sheet — a contact sheet cannot be alpha-cut per object.
- **Verify before using:** `ls -la` the path, Read the file, and if the asset joins an existing set, compare luminance numerically (PIL mean/median) against that set rather than trusting the eye.
