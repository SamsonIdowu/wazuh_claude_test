# Auto-Termination & TTL Management

## ⏱️ Overview

All deployed resources have a **1-hour (60 minute) default Time-To-Live (TTL)**. After this period, the infrastructure will be automatically terminated to prevent unexpected costs.

```
DEPLOYMENT → 1 HOUR → AUTO-TERMINATE (unless extended)
```

## 📊 Default Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| `resource_ttl_minutes` | 60 | Resources terminate after 1 hour |
| `enable_auto_termination` | true | Auto-termination is active |

## ⏳ What Happens at Each Stage

### During Deployment (terraform apply)
1. ✅ Instances created with TTL tags
2. ✅ Info file created: `TTL_AND_EXTENSION.txt`
3. ✅ Terraform outputs show TTL countdown instructions

### During Operation (0-60 minutes)
1. ✅ You have full access to Wazuh Dashboard
2. ✅ You can run tests and validation
3. ⚠️ Timer counting down in background

### At 60 Minutes
1. ⏰ Termination window opens
2. 📢 Resources are marked for termination
3. 🛑 Auto-cleanup will occur

## 🛑 Preventing Termination

You have three options:

### Option 1: Extend TTL (Recommended for continuing work)

**Steps:**
1. Edit `terraform/terraform.tfvars`
2. Change the TTL value:
   ```hcl
   resource_ttl_minutes = 120  # Extend to 2 hours
   ```
3. Run:
   ```bash
   cd terraform
   terraform apply
   ```

**Result:** Resources continue for another hour (or your specified duration)

---

### Option 2: Disable Auto-Termination (For long-running tests)

**Steps:**
1. Edit `terraform/terraform.tfvars`
2. Add/modify:
   ```hcl
   enable_auto_termination = false
   ```
3. Run:
   ```bash
   cd terraform
   terraform apply
   ```

**Result:** Resources run indefinitely (manually destroy when done)

---

### Option 3: Cleanup Immediately

**Steps:**
```bash
cd terraform
terraform destroy
```

**Result:** All resources immediately terminated and cleaned up

---

## 📝 Common Scenarios

### Scenario 1: Running Tests (0-30 min)
```
Time: 0-30 min
Action: Run your tests normally
TTL: No action needed
```

### Scenario 2: Tests Taking Longer Than Expected
```
Time: 50 minutes elapsed
Action: Extend TTL to 120 minutes
Command: 
  terraform/terraform.tfvars → resource_ttl_minutes = 120
  terraform apply
Result: Continue testing for another hour
```

### Scenario 3: Completed, Need Cleanup
```
Time: 45 minutes elapsed
Action: Destroy resources
Command: terraform destroy
Result: Immediate cleanup, stop paying
```

### Scenario 4: Multi-Phase Testing
```
Time: 0 min    → Deploy (TTL = 60 min)
Time: 30 min   → Testing phase 1 complete
Time: 50 min   → Extend to 120 min
Time: 100 min  → Testing phase 2 complete
Time: 110 min  → Destroy
```

---

## 🔧 Terraform Variables Reference

### resource_ttl_minutes
- **Type:** number
- **Default:** 60
- **Range:** 1-1440 (1 minute to 1 day)
- **Effect:** Controls auto-termination time
- **Example:**
  ```hcl
  resource_ttl_minutes = 180  # 3 hours
  ```

### enable_auto_termination
- **Type:** boolean
- **Default:** true
- **Effect:** Enables/disables auto-termination
- **Example:**
  ```hcl
  enable_auto_termination = false  # Never auto-terminate
  ```

---

## 📋 Instance Tags

All instances are tagged with:
- `TTL_Minutes` - The TTL value in minutes
- `AutoTermination` - Whether auto-termination is enabled
- `CreatedAt` - Timestamp of creation

View tags via AWS Console:
1. Go to EC2 → Instances
2. Select instance
3. Tags tab shows TTL information

---

## 💰 Cost Implications

### Example Cost Breakdown (1 Hour Default)

| Resource | Price/Hour | 1-Hour Cost | Notes |
|----------|-----------|-----------|-------|
| Wazuh Server (t3.xlarge) | $0.1664 | ~$0.17 | Testing |
| Agent (t3.medium) | $0.0416 | ~$0.04 | Testing |
| EBS Volumes | ~$0.003 | <$0.01 | 50GB total |
| **Total** | | **~$0.22** | Per 1-hour run |

**Extended to 2 hours:** ~$0.44
**Extended to 4 hours:** ~$0.88

---

## ⚠️ Important Notes

### Auto-Termination Behavior
- ✅ Works transparently in background
- ✅ Terraform state is updated to reflect TTL
- ✅ All AWS resources are properly terminated
- ✅ Volumes and snapshots are deleted

### No Response = Cleanup
- After TTL expires with `enable_auto_termination = true`
- Resources are automatically destroyed
- No notification emails are sent
- No additional action required to cleanup

### Manual Control Always Available
- You can always extend TTL
- You can always disable auto-termination
- You can always destroy manually
- Full control remains with terraform commands

---

## 🚀 Workflow Example

```bash
# 1. Deploy with default 1-hour TTL
cd terraform
terraform apply

# 2. Work for 30 minutes
# ... run tests, configure EOL detection ...

# 3. Realize you need more time (50 minutes elapsed)
# Edit terraform/terraform.tfvars:
#   resource_ttl_minutes = 120

# 4. Extend the TTL
terraform apply

# 5. Continue work for another hour
# ... more testing ...

# 6. All done, cleanup
terraform destroy
```

---

## 📞 Quick Reference

| Need | Command |
|------|---------|
| Check TTL status | `terraform output resource_ttl_minutes` |
| Extend TTL | Edit `.tfvars` → `terraform apply` |
| Disable auto-termination | Edit `.tfvars` → `terraform apply` |
| Destroy immediately | `terraform destroy` |
| View instance tags | AWS Console → EC2 → Instances → Tags |

---

**Last Updated:** 2026-07-27
**Version:** 1.0
