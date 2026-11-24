# Automated Cloud Deployment Platform

`git push` → **test → security scan → build → Terraform provision → deploy → smoke test → monitor**

```
GitHub push
   │
   ├─ test      flake8, pytest (80% coverage gate)
   ├─ security  gitleaks (secrets) · bandit (SAST) · pip-audit (deps) · Checkov (Terraform)
   ├─ build     Docker build · Trivy image scan · push to ECR
   ├─ plan      (PRs only) terraform fmt/validate/plan
   └─ deploy    terraform apply → ECS rolling deploy → smoke test
                      │
        AWS: VPC · ALB · ECS Fargate · ECR · autoscaling
             CloudWatch dashboard · alarms · log-based error metric · SNS email alerts
             Auto-rollback: ECS circuit breaker + 5xx alarm
```

## Layout
| Path | Purpose |
|---|---|
| `app/` | Sample Flask service, tests, Dockerfile |
| `bootstrap/` | One-time: Terraform state bucket + GitHub OIDC role |
| `infra/` | Terraform for the app environment + monitoring |
| `scripts/smoke_test.sh` | Post-deploy verification (checks the new version is live) |
| `.github/workflows/pipeline.yml` | The pipeline |

## Setup

1. **Bootstrap AWS (once, with admin creds):**
   ```bash
   cd bootstrap
   terraform init
   terraform apply -var github_repo=YOUR_ORG/YOUR_REPO -var state_bucket_name=YOUR-UNIQUE-BUCKET
   ```
   Note the `role_arn` output.

2. **GitHub repo settings**
   - Secret: `AWS_ROLE_ARN` = role ARN from step 1
   - Variables: `AWS_REGION` (e.g. `ap-south-1`), `TF_STATE_BUCKET`, `ALERT_EMAIL`, optional `CERTIFICATE_ARN`
   - Environment `production` (Settings → Environments); add required reviewers for a manual approval gate

3. **Push to `main`.** The first run creates all infrastructure; later runs just roll out the new image.
   The `app_url` and CloudWatch dashboard link appear in the run summary. Confirm the SNS subscription email.

## Run locally
```bash
cd app && pip install -r requirements-dev.txt && pytest
docker build -t app . && docker run -p 8080:8080 app
```

## Monitoring
- **CloudWatch dashboard:** requests, 4xx/5xx, p50/p95/p99 latency, CPU/memory, healthy targets, recent errors
- **Alarms → SNS email:** 5xx, p95 latency, unhealthy hosts, CPU, memory, app ERROR logs
- **`/metrics`:** Prometheus endpoint for scraping if you add Prometheus/Grafana

## Rollbacks
ECS deployment circuit breaker rolls back if new tasks can't become healthy, and the 5xx alarm rolls
back a deploy that starts erroring. The smoke test then fails the pipeline because the expected version
isn't live. To redeploy an older commit manually, re-run the workflow for that commit.

## Teardown
```bash
cd infra && terraform init -backend-config=... && terraform destroy -var image_tag=x
```

## Production hardening checklist
- Replace `AdministratorAccess` on the pipeline role with a scoped policy
- Use private subnets + NAT (or VPC endpoints) for tasks; add WAF on the ALB
- Set `CERTIFICATE_ARN` for HTTPS; add a Route 53 record
- Separate `staging` / `production` environments (copy workflow, change `ENVIRONMENT`)
- Pin GitHub Actions to commit SHAs; enable Dependabot
- Approx. cost: ~$16 ALB + ~$18 for 2 small Fargate tasks per month, plus CloudWatch
