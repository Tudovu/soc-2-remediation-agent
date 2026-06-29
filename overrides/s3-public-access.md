# Override: S3 public access

**Applies to:** `s3_bucket_public_access`, `s3_account_level_public_access_blocks`, `s3_bucket_policy_public_write_access`, related S3 public exposure checks.

**Mode:** Investigate → patch (with human approval)

**SOC 2:** CC6.6, C1

---

## Why this override exists

Prowler's default remediation (enable Block Public Access) is often **technically correct and operationally wrong**. Teams frequently have **intentional** public buckets (marketing assets, static sites) while account-level BPA is disabled. Applying fixes blindly can break CloudFront, public documentation sites, or partner integrations.

---

## Phase 2 — Investigation checklist

Run all of the following before proposing a patch.

### Account level

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws s3control get-public-access-block --account-id "$ACCOUNT_ID" --region us-east-1
```

Record each of the four account-level flags (`BlockPublicAcls`, `IgnorePublicAcls`, `BlockPublicPolicy`, `RestrictPublicBuckets`).

### Per failing bucket

```bash
BUCKET="{bucket-name}"
aws s3api get-public-access-block --bucket "$BUCKET"
aws s3api get-bucket-policy --bucket "$BUCKET" 2>/dev/null || echo "No bucket policy"
aws s3api get-bucket-acl --bucket "$BUCKET"
aws s3api get-bucket-encryption --bucket "$BUCKET"
aws s3api get-bucket-tagging --bucket "$BUCKET" 2>/dev/null || true
```

### Dependency discovery

1. **CloudFront** — list distributions; check origins pointing at this bucket:

   ```bash
   aws cloudfront list-distributions --query "DistributionList.Items[?Origins.Items[?DomainName.contains(@, \`$BUCKET\`)]].[Id,DomainName,Origins]" --output table
   ```

2. **IAM** — grep infra repo for bucket name, ARN, and `s3://` URLs.

3. **Lambda / ECS task defs** — search env vars and IAM policies for bucket references.

4. **CloudTrail S3 data events** (if enabled) — who reads/writes anonymously or from unexpected principals.

### Classify each bucket

| Classification | Indicators | Remediation direction |
|----------------|------------|------------------------|
| **Accidental public** | No documented purpose; `Principal: "*"` on sensitive data | Block public access; fix policy |
| **Intentional public** | Marketing/static assets; documented in runbook | Keep bucket exception OR migrate to CloudFront OAC/OAI; **still enable account-level BPA** |
| **Public via CloudFront only** | Bucket should be private; CF serves content | Private bucket + Origin Access Control |

---

## Phase 3 — Required human questions

1. Is bucket `{name}` **intentionally** public? If yes, what is the business purpose and data classification?
2. Should we enable **account-level** Block Public Access while keeping a documented exception for specific buckets?
3. If CloudFront serves this bucket, should we migrate to **Origin Access Control** (bucket private, CF public)?
4. Is there a maintenance window if CloudFront or app integrations need updating?

Do not proceed until answered.

---

## Phase 4 — Patch guidance

### Preferred order

1. **Enable account-level BPA** (CloudFormation `AWS::S3::AccountPublicAccessBlock` — all four flags `true`) unless a documented exception blocks it.
2. For **intentional public buckets**: document exception in runbook; consider moving public read to CloudFront with private origin instead of `Principal: "*"` on the bucket.
3. For **accidental public buckets**: enable bucket-level public access block + remove public policy statements.

### Prowler snippet handling

- Use Prowler's CloudFormation/Terraform snippet as a **starting point**.
- If account BPA would block an approved public bucket, **do not** apply account BPA without the exception documented and CloudFront/OAC path confirmed.
- Separate PRs are acceptable: (A) account BPA, (B) bucket-specific hardening.

### Example TSC evidence note

> Account-level S3 Block Public Access enabled via PR #{n}. Marketing bucket `{name}` retained public read via CloudFront OAC per approved exception documented in `compliance/runbooks/s3-buckets.md`.

---

## Phase 5 — Runbook template

Update `compliance/runbooks/s3-buckets.md` with:

- Bucket inventory (name, purpose, public/private, encryption)
- Account BPA status and date enabled
- Documented exceptions (if any) with approver and review date
- Verification command: `aws s3control get-public-access-block --account-id ...`
