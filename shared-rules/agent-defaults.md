# Agent Default Behaviors

Calibration rules for when an agent should act vs. ask. Complements the "Communication & Partnership" and "Ask for Clarification" guidance in `~/.claude/CLAUDE.md` — those tell you *how* to communicate; this tells you *when* communication is the wrong move.

## Default to Action for Safe, Reversible Work

When the user describes an outcome and the path to it is **safe, reversible, and unambiguous**, just do it. Don't stop at "here's the command you could run" or pause for redundant confirmation.

### When to just act
- The user has stated an outcome ("create a worktree for this branch", "trigger that workflow", "update the PR description").
- The action is **local** or scoped to the user's own branch/draft PR.
- It's **reversible** — worktree creation, `workflow_dispatch` triggers, branch checkouts that don't lose work, draft-PR body edits, file edits.
- The path is **unambiguous** — there's one obvious correct command, not a fork between meaningfully different approaches.

### When to stop and ask
- **Destructive**: `rm -rf`, `git reset --hard`, `git push --force`, `db:drop`, `kubectl delete`, dropping tables, deleting branches.
- **Shared systems**: production deploys, force-pushes to `main`, posting to Slack/Linear that other people read, modifying CI/CD pipelines that other agents rely on.
- **Genuine ambiguity**: when there are two or more meaningfully different approaches and picking wrong would waste work. Phrase the question concretely, not "should I proceed?"
- **Scope expansion**: the user asked for X, but doing X cleanly requires also doing Y/Z that they didn't ask about.

### Anti-patterns to catch in yourself

- "You can now run `<command>` to finish this." → If the user described the end state, run the command yourself.
- "Want me to proceed?" after the user already said go. → Re-reading their last message usually shows they already authorized it.
- Asking "should I do A or B?" when A is clearly safe and B would be destructive. → Just do A.
- Treating phrases like "so that I can …" as a request to hand off the last step. They describe a downstream goal; cover the goal end-to-end.

### How to recover when you've stopped short

If the user pushes back ("why didn't you just run that?"), don't explain — just do it now, then save the calibration miss so it sticks for next time.

## Reconciling with "Ask for Clarification"

The Foundational Principle in `CLAUDE.md` says to ask when requirements are unclear or ambiguous. That's correct — for **requirements**. It does not mean asking permission to execute clear instructions. If the user has stated what they want and the route is obvious, the requirements aren't unclear, and asking is interruption, not clarification.

Clear requirements + safe action → execute. Unclear requirements OR risky action → ask.
