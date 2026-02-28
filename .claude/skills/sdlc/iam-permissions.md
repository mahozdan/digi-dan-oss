# iam-permissions

## Principles
- **Least privilege**: grant only what's needed for the specific task
- **Split by lifecycle**: separate deploy, destroy, and runtime policies
- **Resource-scope everything possible**: use ARNs, not `*`
- **Roles for services, users for humans**: Lambda/ECS/EC2 get roles; CI/CD and humans get users

## IAM Policy Validator Quirks

The AWS IAM policy validator (in the console) flags actions that don't support resource-level permissions. This does NOT mean the action is invalid — it means the action can't be scoped to a specific ARN.

### Resource Types Column Rules
Check the [IAM Actions Reference](https://docs.aws.amazon.com/service-authorization/latest/reference/) for each service:

| Column Value | Meaning | Resource Value |
|---|---|---|
| Resource type with `*` (asterisk) | **Required** resource-level permission | Use specific ARN |
| Resource type without `*` | **Optional** resource-level permission | Use `"*"` to avoid validator warnings |
| Empty column | No resource type support | Must use `"*"` |

### Fix: Split Statements by Resource Support
When a statement mixes actions that support resource-level permissions with those that don't, split them:

```json
{
  "Sid": "S3BucketRead",
  "Effect": "Allow",
  "Action": ["s3:ListBucket", "s3:GetBucketLocation"],
  "Resource": "*"
},
{
  "Sid": "S3BucketManage",
  "Effect": "Allow",
  "Action": ["s3:CreateBucket", "s3:PutBucketPolicy"],
  "Resource": "arn:aws:s3:::my-bucket"
}
```

## Known AWS Inconsistencies

| Action | Validator Says | Reality |
|---|---|---|
| `s3:GetBucketObjectLockConfiguration` | Not recognized | Required by S3 API (Terraform needs it). Keep it despite warning. |
| `apigateway:TagResource` | Not a valid action | Correct — API Gateway uses HTTP verbs on `/tags/*` resource |
| `s3:GetObjectLockConfiguration` | Not recognized | Not a real action; the correct one is the bucket-level variant above |

## Service-Specific Notes

### S3
Actions with **optional** resource types (use `Resource: "*"`):
- `s3:ListBucket`
- `s3:GetBucketLocation`
- `s3:GetBucketAcl`
- `s3:GetBucketCORS`
- `s3:GetBucketPolicy`

### API Gateway
HTTP verb actions (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`) all have optional resource types. Use `Resource: "*"` for all of them. Do NOT use `apigateway:TagResource` — use HTTP verbs on `/tags/*`.

### CloudWatch Logs
- `logs:DescribeLogGroups` has empty resource types — must use `Resource: "*"`
- Other log actions (`CreateLogGroup`, `PutRetentionPolicy`, etc.) support ARN scoping

### Lambda
- `lambda:PutFunctionConcurrency` is needed if setting `reserved_concurrent_executions` in Terraform
- `iam:PassRole` is required for any principal that assigns a role to a Lambda function

### SES
- Lock with region condition when possible:
```json
"Condition": {
  "StringEquals": {
    "aws:RequestedRegion": "il-central-1"
  }
}
```

## Roles vs Users

| Entity | Type | Use Case |
|---|---|---|
| CI/CD deployer | IAM User | Runs Terraform apply |
| CI/CD destroyer | IAM User | Runs Terraform destroy |
| Lambda function | IAM Role | Runtime execution identity |
| EC2 instance | IAM Role | Instance profile |

### Lambda Role Setup (Manual)
1. Create role in IAM Console: **Trusted entity** = AWS Service, **Use case** = Lambda
2. Trust policy is auto-configured (no need for a separate trust policy file)
3. Add inline policy with runtime permissions (DynamoDB, SES, CloudWatch Logs, etc.)
4. Reference role ARN in Terraform via variable:
```hcl
variable "lambda_role_arn" {
  description = "ARN of the manually-created Lambda execution role"
  type        = string
  default     = "arn:aws:iam::ACCOUNT_ID:role/my-lambda-role"
}
```

## Policy File Organization
```
iam/policies/
  iam-policy-deploy.json       # Deploy/update permissions
  iam-policy-destroy.json      # Teardown permissions
  iam-lambda-permissions-policy.json  # Lambda runtime permissions
```

## Checklist
- [ ] Each action checked against IAM Actions Reference for resource type support
- [ ] Actions split into separate statements by resource type support
- [ ] No `apigateway:TagResource` (use HTTP verbs instead)
- [ ] `s3:GetBucketObjectLockConfiguration` kept despite validator warning
- [ ] Lambda uses a Role, not a User
- [ ] `iam:PassRole` included for any principal that assigns roles
- [ ] Region conditions on services that support them (SES, etc.)
- [ ] Deploy and destroy policies are separate files
