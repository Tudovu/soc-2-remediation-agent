# Override: IAM identity controls

**Applies to:** MFA findings, access review gaps, excessive admin privileges, root usage — controls requiring **human attestation**.

**Mode:** Investigate → human gate (no auto-apply for identity changes)

**SOC 2:** CC6.1, CC6.2, CC6.3

---

## Why this override exists

IAM identity controls cannot be fully closed by automation:

- **MFA** requires each user to enroll a device
- **Access reviews** require a manager/owner to attest access is still needed
- **Removing AdministratorAccess** requires designing a least-privilege model first

Claude prepares evidence and checklists. Claude does **not** mark these findings "fixed" without human completion.

---

## Phase 2 — Investigation checklist

```bash
aws iam get-account-summary
aws iam list-users --query 'Users[*].[UserName,CreateDate,PasswordLastUsed]' --output table

for USER in $(aws iam list-users --query 'Users[*].UserName' --output text); do
  echo "=== $USER ==="
  aws iam list-mfa-devices --user-name "$USER"
  aws iam list-access-keys --user-name "$USER" --query 'AccessKeyMetadata[*].[AccessKeyId,Status,CreateDate]' --output table
  aws iam list-groups-for-user --user-name "$USER" --query 'Groups[*].GroupName' --output text
  aws iam list-attached-user-policies --user-name "$USER" --query 'AttachedPolicies[*].PolicyArn' --output text
done

aws iam list-groups --query 'Groups[*].GroupName' --output text | while read G; do
  echo "=== group: $G ==="
  aws iam list-attached-group-policies --group-name "$G"
done

aws iam generate-credential-report 2>/dev/null
aws iam get-credential-report --query 'Content' --output text | base64 -d | head -20
```

Document:

| User / group | MFA | Keys | Policies | Risk |
|--------------|-----|------|----------|------|
| (fill per user) | Yes/No | active keys | Admin? | Human/CI/break-glass |

Flag:

- Users with `AdministratorAccess` or admin-equivalent inline policies
- Active access keys on human users (prefer SSO + role assumption)
- Root account access keys (must be none)
- Shared/ci users without MFA

---

## Phase 3 — Required human questions

1. Which users are **human** vs **CI/automation**? (different remediation paths)
2. For human users: who will **enroll MFA** and by when?
3. For admin access: what is the **target permission model** (IAM Identity Center, scoped roles, break-glass)?
4. For CI users (e.g. `ci-deployer`): is **GitHub OIDC** ready before key deletion?
5. Who owns the **quarterly access review** process and sign-off?

**Stop after Phase 3 for MFA and access review findings.** Produce checklist + evidence template only.

---

## Phase 4 — What Claude delivers (not auto-apply)

### MFA enrollment checklist

Create `compliance/evidence/CC6.1/{date}-iam-mfa/checklist.md`:

```markdown
# MFA enrollment checklist

| User | Console access? | MFA enrolled | Date | Enrolled by |
|------|-----------------|--------------|------|-------------|
| ...  | Y/N             | Y/N          |      | self        |

## Steps for each human user
1. IAM → Users → Security credentials → Assign MFA device
2. Verify: `aws iam list-mfa-devices --user-name {user}`
3. Screenshot or CLI output saved to this folder
```

### Admin reduction plan (draft only)

- Propose scoped policies based on CloudTrail `lookup-events` for actual API usage (last 30 days) if available
- **Do not attach policies** until human approves target model
- Recommend IAM Identity Center for human access

### Access review template

`compliance/evidence/CC6.1/{date}-access-review/review.md`:

| User | Groups / policies | Last activity | Still required? | Reviewer | Date |
|------|-------------------|---------------|-----------------|----------|------|

Reviewer must sign (name + date). Claude fills inventory; human fills attestation columns.

---

## Phase 5 — Runbook

Create or update `compliance/runbooks/iam-access.md`:

- Human access via SSO/Identity Center (target state)
- MFA required for all console users
- No long-lived keys on human users
- CI via OIDC roles only
- Quarterly access review cadence and owner
- Break-glass procedure (separate account or emergency role)

---

## When this finding can move to "remediated"

Only when evidence folder contains:

- MFA: CLI/console proof for **every** human console user
- Admin: updated IAM policies merged + CloudTrail shows no daily admin usage
- Access review: signed review spreadsheet for the audit period

Claude may re-run Prowler to verify `iam_user_mfa_enabled_*` passes after human enrollment.

Prioritize: MFA for humans → OIDC for CI → scoped roles replacing admin group.
