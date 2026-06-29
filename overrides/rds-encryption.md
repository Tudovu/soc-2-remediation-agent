# Override: RDS encryption at rest

**Applies to:** `rds_instance_storage_encrypted`, `rds_snapshots_encrypted`, related RDS storage encryption checks.

**Mode:** Investigate → procedure (not a single-patch fix)

**SOC 2:** C1.1, CC6.7

---

## Why this override exists

RDS storage encryption **cannot be toggled in place**. Prowler may show a CloudFormation property (`StorageEncrypted: true`), but applying that to an existing instance requires **snapshot → encrypted copy → restore → cutover**. Claude must produce a migration procedure, not imply a one-click fix.

---

## Phase 2 — Investigation checklist

```bash
DB_ID="{db-instance-identifier}"
aws rds describe-db-instances --db-instance-identifier "$DB_ID" --region us-east-1
```

Capture and document:

| Field | Why it matters |
|-------|----------------|
| `StorageEncrypted` | Current state (expect `false`) |
| `Engine` / `EngineVersion` | Restore compatibility |
| `DBInstanceClass` | Sizing for restore |
| `AllocatedStorage` | Snapshot size / duration |
| `MultiAZ` | Failover during cutover |
| `BackupRetentionPeriod` | Pre-migration backup safety |
| `DeletionProtection` | Prevent accidental delete mid-migration |
| `PubliclyAccessible` | Should be `false` |
| `VpcSecurityGroups` | App connectivity after restore |
| `DBSubnetGroupName` | Must match for restore |
| `KmsKeyId` | Target CMK (create one if none exists) |

### Connectivity blast radius

```bash
aws ec2 describe-security-groups --group-ids {sg-from-rds}
```

Identify application tier security groups allowed on port 5432 (or relevant port). Grep infra repo (often **external Terraform**) for:

- `aws_db_instance` / `aws_rds_cluster` resources
- Connection strings, Secrets Manager references
- Read replicas or DMS tasks

### Downtime estimate

- Snapshot: minutes to hours depending on size
- Encrypted copy: additional time
- Restore: new endpoint hostname unless DNS/parameter update planned
- Application restart / connection pool refresh required

---

## Phase 3 — Required human questions

1. What is the **acceptable downtime window** (or is blue/green required)?
2. Where is the **Terraform/CloudFormation source of truth** for this RDS instance?
3. Should we use **AWS-managed RDS key** or a **customer-managed KMS CMK**?
4. Is a **pre-migration manual snapshot** required before any changes?
5. Who validates application connectivity post-cutover?

Do not open a "flip StorageEncrypted" PR without answers.

---

## Phase 4 — Procedure (ordered steps)

Document this in the PR body and `compliance/runbooks/rds.md`. Adapt to customer's IaC location.

### Pre-migration

1. Create manual snapshot: `{db-id}-pre-encryption-{date}`
2. Enable `DeletionProtection` if not set (temporary safety)
3. Notify stakeholders of maintenance window

### Migration (AWS console or CLI — human executes or approves each step)

```bash
# 1. Snapshot
aws rds create-db-snapshot --db-instance-identifier "$DB_ID" --db-snapshot-identifier "${DB_ID}-pre-encrypt-$(date +%Y%m%d)"

# 2. Copy snapshot with encryption (after snapshot available)
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier "${DB_ID}-pre-encrypt-..." \
  --target-db-snapshot-identifier "${DB_ID}-encrypted-copy" \
  --kms-key-id "{kms-key-arn}" \
  --source-region us-east-1

# 3. Restore to new encrypted instance
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "${DB_ID}-encrypted" \
  --db-snapshot-identifier "${DB_ID}-encrypted-copy" \
  ...
```

### IaC update (PR target)

Update Terraform/CloudFormation in the **infra repo** (not this skills repo):

- `storage_encrypted = true`
- `kms_key_id` if using CMK
- Consider increasing `backup_retention_period` and enabling `deletion_protection` in same change set

### Cutover

1. Stop app writes (maintenance mode) or use DNS swap
2. Update connection string / Secrets Manager secret to new endpoint
3. Verify app health checks
4. Decommission old unencrypted instance after retention period

### What Claude puts in the PR

- Terraform/CloudFormation diff for **future state** (encrypted instance definition)
- **NOT** a claim that merging alone encrypts the live instance
- Step-by-step runbook with rollback (restore from pre-encryption snapshot)

---

## Phase 5 — Evidence

`compliance/evidence/C1.1/{date}-rds_instance_storage_encrypted/`:

- `finding.json`
- `impact-analysis.md` (connectivity, downtime, IaC location)
- `decision-log.md` (maintenance window, KMS choice)
- `migration-runbook.md` (ordered steps)
- `verification.json` (post-cutover `describe-db-instances` showing `StorageEncrypted: true`)

---

## Rollback

- Fail cutover → revert connection string to original endpoint
- Restore from `{db-id}-pre-encryption-{date}` snapshot if new instance corrupt
- Keep unencrypted instance until encrypted instance validated (do not delete early)
