# Override: IAM configuration (automatable with approval)

**Applies to:** Account password policy, unused/old access keys, root access key presence, some overly permissive managed policy attachments.

**Mode:** Investigate → patch (with human approval)

**SOC 2:** CC6.1, CC6.3

---

## Distinction from `iam-identity.md`

| `iam-identity.md` | `iam-config.md` |
|-------------------|-----------------|
| MFA enrollment, access reviews, admin model | Password policy, key rotation, policy attachments |
| Human gate — no auto-apply | Can ship CloudFormation / IAM API changes via PR |
| Checklist + attestation | Patch + verify |

---

## Phase 2 — Investigation

### Password policy

```bash
aws iam get-account-password-policy 2>&1
# NoSuchEntity = no policy configured
```

SOC 2 typical minimums (adjust to org policy):

- Minimum length ≥ 14
- Require uppercase, lowercase, numbers, symbols
- Max password age 90 days (or align with SSO — document if SSO handles this)
- Prevent password reuse

### Access keys

```bash
for USER in $(aws iam list-users --query 'Users[*].UserName' --output text); do
  aws iam list-access-keys --user-name "$USER" --output table
done
```

Flag keys older than 90 days or keys on human users where SSO should be used.

### Root account

```bash
aws iam get-account-summary --query 'SummaryMap.AccountAccessKeysPresent'
```

Must be `0`. If `1`, escalate immediately — root key deletion is human-initiated with root login.

### Overly permissive policies

```bash
aws iam list-entities-for-policy --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
```

Cross-reference with CloudTrail (if enabled) for which principals actually need admin.

---

## Phase 3 — Human questions

1. Approve password policy parameters (length, complexity, rotation)?
2. For each old/unused access key: deactivate now or after CI migration?
3. For AdministratorAccess attachments: approve scoped replacement policy (attach draft)?
4. Confirm no application depends on the key/policy being removed (blast radius).

---

## Phase 4 — Patch guidance

### Password policy (CloudFormation)

```yaml
Resources:
  AccountPasswordPolicy:
    Type: AWS::IAM::AccountPasswordPolicy
    Properties:
      MinimumPasswordLength: 14
      RequireUppercaseCharacters: true
      RequireLowercaseCharacters: true
      RequireNumbers: true
      RequireSymbols: true
      MaxPasswordAge: 90
      PasswordReusePrevention: 24
      AllowUsersToChangePassword: true
      HardExpiry: false
```

Or equivalent Terraform `aws_iam_account_password_policy`.

**Note:** If org uses SSO-only console access, document that password policy applies to local IAM users only; SSO IdP policy covers humans.

### Access key rotation

Prefer **OIDC migration** over rotation for CI users. For rotation:

1. Create second key → update secret store → delete old key (two-step PR)
2. Never commit keys to git

### Detach AdministratorAccess

Only after `iam-identity.md` target permission model is approved. PR should:

- Attach scoped policy (e.g. `ReadOnlyAccess` + specific service policies)
- Detach `AdministratorAccess` from group/user
- Include rollback: re-attach if break-glass needed (document incident)

---

## Phase 5 — Evidence

`compliance/evidence/CC6.1/{date}-{check-id}/`:

- `finding.json`
- `remediation/` — CFN or Terraform patch
- `verification.txt` — CLI output after merge:

  ```bash
  aws iam get-account-password-policy
  aws iam list-access-keys --user-name {user}
  ```

---

## Prowler snippet handling

Use Prowler IaC for password policy and key age findings. **Override** when:

- CI user keys should be deleted (not rotated) after OIDC is live
- Admin policy detachment requires custom scoped policy not in Prowler defaults
