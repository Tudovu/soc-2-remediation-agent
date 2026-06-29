# Worked examples

This directory will contain end-to-end runs: Prowler finding → impact analysis → PR → evidence.

## Planned examples

| Example | Check | Mode |
|---------|-------|------|
| `s3-account-bpa/` | `s3_account_level_public_access_blocks` | Investigate → patch |
| `rds-encryption/` | `rds_instance_storage_encrypted` | Investigate → procedure |
| `iam-mfa/` | `iam_user_mfa_enabled_console_access` | Human gate |

## How to add an example

After a successful remediation:

1. Copy sanitized artifacts (strip account IDs if publishing publicly)
2. Include: `finding.json`, `impact-analysis.md`, `decision-log.md`, sample PR description
3. Note which AWS profile and infra repo path were used (sanitized)
