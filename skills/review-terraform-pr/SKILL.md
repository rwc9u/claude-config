---
name: review-terraform-pr
description: This skill should be used when the user asks to "review this terraform PR", "review terraform PR <number>", "check the terraform plans", "are these plan changes expected", or invokes /review-terraform-pr. It produces a reviewer's verdict on a Terraform PR after checking every Terraform Cloud plan posted on the PR and confirming that each planned change belongs to this PR.
argument-hint: "[pr-number] [low|medium|high|xhigh|max] [--file] [--desk]"
model: opus
---

# Review Terraform PR

Review a Terraform PR the way `/review-pr` does, plus the step that matters most
for infrastructure: every Terraform Cloud plan on the PR is read, and every
planned change is traced to this PR's diff. A green plan check means only that
the plan ran; "1 to destroy" still shows green.

Follow the `review-pr` skill (`~/.claude/skills/review-pr/SKILL.md`) for
arguments, the verdict, the explainer, reporting, the `--desk` verdict file and
filing. This skill replaces its step 2 with steps 2–4 below.

```bash
PLANS="ruby ~/.claude/skills/review-terraform-pr/scripts/tfc_plans.rb"
```

## 1. Gather context

As in `review-pr` step 1. Also pin the head SHA (`gh pr view <n> --json headRefOid`)
and name it in the report: plan checks belong to one commit, and a push mid-review
replaces them.

## 2. Read the diff for intent

`gh pr diff <n>`. Write down, before looking at any plan:

- the resources, modules, variables and tfvars the PR touches
- which workspaces each change should reach (by directory, tfvars file, or an
  environment conditional such as `count = var.environment == "production"`)
- what each should do: create, update in place, replace, or destroy

## 3. Read every plan

Run `$PLANS <owner/repo> <n>`. It prints one block per `Terraform Cloud/` check
on the head commit: the run, its commit, the workspace's last apply, every
non-no-op change (with changed attributes for updates), drift, and output changes.

Every block gets reviewed. Stop and say so, without a verdict, when:

- a plan is still running (`!! plan has not finished`): re-run the script once it finishes
- a plan errored, or the script couldn't read it: open the run URL and report the error
- a block says `!! STALE`: the plan is for an older commit, so it doesn't show this
  PR's changes. Ask for a re-plan (a new push, or "Start new plan" in TFC)
- there are no Terraform Cloud checks but the PR changes `.tf` or `.tfvars` files

## 4. Check each change belongs to this PR

For every change in every workspace, mark it as one of:

- **Expected**: matches an item from step 2, including its attribute values (for
  example `engine_version: 1.5.16 → 1.6.22` matches the version in the diff)
- **From main**: not in this diff, but main has commits since the workspace's last
  apply that cause it. Check with `git fetch origin main` and
  `git log --oneline <last-apply-sha>..origin/main -- <paths>`. Not this PR's
  doing, but say it will apply alongside this PR
- **Drift**: the address also appears under drift and the change puts it back to
  what the code says. Say whether that revert is safe
- **Unexplained**: none of the above. This is a blocking item

Also check the reverse:

- a workspace step 2 expects to change that planned no changes
- a change that reached a workspace it shouldn't, such as a staging-only change
  showing up in production

For each replace or destroy, give the `replaced because` reason. Then run the
`code-review` skill on the PR at the effort level given (default `low`), as in
`review-pr` step 2.

## 5. Verdict

As in `review-pr` step 3: blocking items default to **Comment**. Only these
Terraform cases warrant **Request changes**:

- destroying or replacing a stateful resource (RDS/Aurora, ElastiCache with
  data, S3 with objects, EBS, DynamoDB) without a stated plan for the data
- IAM opened to `*` actions or resources, or a trust policy opened to any principal
- a security group or network ACL opened to `0.0.0.0/0` on a non-public port
- an unexplained change in a production workspace

## 6. Explainer, report, and filing

Follow `review-pr` steps 4–6. The explainer's visual is a table with one row per
workspace: the changes, how each was classified, and a link to the run. Leave
out drift that doesn't touch this PR's resources. In the report, list the
workspaces reviewed and how many changes each had, so nothing goes unreviewed.
