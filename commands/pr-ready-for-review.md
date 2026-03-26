# Mark PR Ready for Review

You are tasked with marking the current branch's pull request as ready for review.

## Process

1. **Identify the current branch and PR**:
   - Get the current branch name with `git rev-parse --abbrev-ref HEAD`
   - Find the PR number for this branch using `GH_PAGER="" gh pr list --head <branch> --json number --jq '.[0].number'`
   - If no PR is found, inform the user that no PR exists for this branch

2. **Mark PR as ready for review**:
   - Use `GH_PAGER="" gh pr ready <pr_number>` to convert from draft to ready state
   - This command will fail gracefully if the PR is already in ready state

3. **Add the run-ci label** (kajabi-products repo only):
   - **Only** if the current repository is `kajabi-products`, use `GH_PAGER="" gh pr edit <pr_number> --add-label "run-ci"` to trigger CI
   - This label tells the CI system to run the full test suite
   - **Skip this step entirely** for all other repositories

4. **Provide feedback**:
   - Show the PR number and URL
   - Confirm that the PR is now ready for review
   - If in kajabi-products, confirm that CI has been triggered

## Example Commands

```bash
# Get current branch
git rev-parse --abbrev-ref HEAD

# Find PR for current branch
GH_PAGER="" gh pr list --head <branch> --json number,url --jq '.[0]'

# Mark as ready
GH_PAGER="" gh pr ready <pr_number>

# Add run-ci label (kajabi-products repo only)
GH_PAGER="" gh pr edit <pr_number> --add-label "run-ci"
```

## Important Notes

- The `GH_PAGER=""` prefix disables the pager for non-interactive execution
- The PR must exist before running this command (use `/create-pr` first if needed)
- If the PR is already ready (not a draft), the `gh pr ready` command may show a warning but won't fail
- The "run-ci" label is specific to the kajabi-products repository — do not add it in other repos
