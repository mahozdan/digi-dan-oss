# Layer 0: Join Site

Standalone deploy layer. No dependencies on any other platform layer.

## Resources

```
S3 Bucket         → community-join-site        → static website hosting, public read
API Gateway HTTP  → community-join-api          → POST /apply, throttle 5/sec burst 10
Lambda            → community-join-apply        → nodejs20.x, 128MB, 10s timeout, concurrency 10
DynamoDB          → community-applications      → on-demand, PK=id(uuid), GSI=email+submitted_at
SES (optional)    →                             → notify admin on new application
```

## Region

`il-central-1` only. Hardcode in provider, never variable.

## Terraform

```
join-site/terraform/main.tf
```

Single file. Provider + S3 bucket + bucket website config + bucket policy (public GetObject) + DynamoDB table (PAY_PER_REQUEST, PITR on) + Lambda function (zip from `../lambda/apply/`) + IAM role (dynamodb:PutItem, logs, ses:SendEmail) + API Gateway HTTP API + route POST /apply + $default stage with auto_deploy + lambda permission.

Variables: `admin_email` (string, default=""), `from_email` (string, default="").

Outputs: `website_url`, `api_url`, `dynamodb_table`.

## Lambda

```
join-site/lambda/apply/index.mjs
```

ES module. Parse body → validate name/email/github/project_idea → PutItem to DynamoDB with id=uuid, status="pending", submitted_at=ISO8601 → optionally SES notify → return 200. CORS headers on all responses. OPTIONS returns 200 empty.

## Frontend

```
join-site/index.html
```

Single HTML file, inline CSS+JS. Dark theme. Form fields: name, email, github, language (select), aws_experience (select), project_idea (textarea), organization, agree (checkbox). POST JSON to `{{API_GATEWAY_URL}}/apply`. After deploy, replace placeholder with `api_url` output then upload:

```bash
aws s3 cp index.html s3://community-join-site/index.html --content-type text/html --region il-central-1
```

## Deploy

```bash
cd join-site/terraform && terraform init && terraform apply  # ~3 min
```

## Cost

~$0-1/mo. All components within free tier at low traffic.