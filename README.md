# SOC 2 Compliance Skills for Claude Code

Clone this repo, run Claude Code in the directory, and remediate AWS SOC 2 findings with engineering judgment — not just scan reports.

Prowler finds issues and supplies IaC snippets. [`CLAUDE.md`](CLAUDE.md) tells Claude how to assess blast radius, ask the right questions, open remediation PRs, and capture audit evidence.

## What you get

- **One procedure file** (`CLAUDE.md`) — five-phase workflow for every finding
- **Targeted overrides** (`overrides/`) — extra context for checks where Prowler's default fix isn't enough (S3 public access, RDS encryption, IAM)
- **Evidence scaffold** (`compliance/`) — impact analyses, runbooks, and TSC-mapped evidence folders

## Quick start

### 1. Prerequisites

```bash
# Python 3.11–3.13 (Prowler may not work on 3.14 yet)
python3.12 -m venv .venv && source .venv/bin/activate
pip install prowler

# Or use the helper script (creates .venv automatically):
./scripts/scan.sh

# AWS CLI with a read-only profile
aws configure --profile your-readonly-profile
export AWS_PROFILE=your-readonly-profile

# Claude Code (https://docs.anthropic.com/en/docs/claude-code)
# GitHub CLI (optional, for PRs)
gh auth login
```

Use a read-only IAM policy for scanning (e.g. `SecurityAudit` + Prowler's [recommended extras](https://docs.prowler.com)). Remediation happens via PR merge, not direct AWS writes from Claude.

### 2. Clone and run

```bash
git clone https://github.com/infranitum/soc2-compliance-skills.git
cd soc2-compliance-skills
claude
```

In Claude Code:

```text
Run a SOC 2 check on our AWS account
```

Or remediate a specific finding (Claude will ask which AWS profile and infra repo to use):

```text
Fix our S3 public access findings
```

### 3. Review and merge

Claude opens **draft PRs** in your infra repo when you provide one. Otherwise it writes patches and evidence under `compliance/`. Review, merge when ready, then re-run Prowler to verify.

## Repository layout

```text
CLAUDE.md                 # Main procedure (loaded automatically by Claude Code)
overrides/                # Check-specific investigation & human-gate rules
compliance/
  impact-analyses/        # Blast radius reports (committed markdown)
  runbooks/               # Per-service runbooks
  evidence/               # TSC-mapped audit evidence
examples/                 # Worked examples (findings → PR → evidence)
```

## Remediation modes

| Mode | Examples | Claude does |
|------|----------|-------------|
| Investigate → patch | CloudTrail, S3 BPA, password policy | AWS queries → questions → PR |
| Investigate → procedure | RDS encryption, OIDC migration | Migration plan; patch is one step |
| Investigate → human gate | MFA, access reviews, admin reduction | Checklist + evidence; no auto-apply |

## Overrides

| File | When it applies |
|------|-----------------|
| [`overrides/s3-public-access.md`](overrides/s3-public-access.md) | Public buckets, account-level BPA |
| [`overrides/rds-encryption.md`](overrides/rds-encryption.md) | Unencrypted RDS instances |
| [`overrides/iam-identity.md`](overrides/iam-identity.md) | MFA, access reviews, least privilege |
| [`overrides/iam-config.md`](overrides/iam-config.md) | Password policy, access key rotation |

## Audit trail

Every remediation produces git artifacts an auditor can review:

- Impact analysis (what would break)
- Decision log (human answers to pre-flight questions)
- PR diff (the actual change)
- Post-merge Prowler verification

See [`examples/README.md`](examples/README.md) for a worked end-to-end run.

## Security

- Scan with read-only credentials
- Claude does not apply CloudFormation or Terraform directly
- No credentials in this repo — use `AWS_PROFILE` or instance roles
- Overrides and evidence may reference resource names; scrub account IDs before publishing examples

## License

MIT — see [LICENSE](LICENSE).

## Credits

Check metadata and remediation snippets sourced from [Prowler](https://github.com/prowler-cloud/prowler) (Apache 2.0). Built for teams pursuing SOC 2 on AWS who want patches, not just dashboards.
