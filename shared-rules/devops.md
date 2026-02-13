# DevOps & EKS Environment Guidelines

## Prerequisites

### VPN Connection Required
You **must be connected to the appropriate VPN** before running any `eks-*` alias. Use the AWS CLI to connect to the VPN first, then run the EKS environment alias.

## EKS Environment Aliases

Each alias performs three steps:
1. **SSO Login** via `aws-sso-util login`
2. **Assume Role** via `awsume` for the target AWS account
3. **Switch Kubernetes Context** via `kubectx` and set namespace to `kajabi-products` via `kubens`

After running an alias, both `kubectl`/`kc` and `aws` CLI commands are available for that environment.

### Available Environments

| Alias | AWS Role | EKS Cluster | Namespace |
|-------|----------|-------------|-----------|
| `eks-dev` | `kajabi-development-admin` | `dev-eks-cluster` | `kajabi-products` |
| `eks-qa` | `kajabi-qa-admin` | `qa-eks-cluster` | `kajabi-products` |
| `eks-perf` | `kajabi-perf-admin` | `perf-eks-cluster` | `kajabi-products` |
| `eks-stage` | `kajabi-staging-admin` | `stage-eks-cluster` | `kajabi-products` |
| `eks-prod` | `kajabi-production-admin` | `prod-eks-cluster` | `kajabi-products` |
| `eks-tools` | `kajabi-tools-admin` | `tools-eks-cluster` | `kajabi-products` |

### Example Usage
```bash
# Connect to VPN first, then:
eks-dev

# Now both kubectl and AWS CLI work for the dev environment
kc get pods
aws s3 ls
```

## Kubernetes Aliases

| Alias | Command | Description |
|-------|---------|-------------|
| `kc` | `kubectl` | Short alias for kubectl |
| `kce <pod>` | `kubectl exec --stdin --tty <pod> -- /bin/bash` | Exec into a pod |
| `k8s-show-ns <namespace>` | Lists all resources in a namespace | Show all resources in a given namespace |

## ECR Login

```bash
ecr-login
```

Authenticates Docker to the Kajabi ECR registry (`937028213865.dkr.ecr.us-east-1.amazonaws.com`).

## Important Notes

- **Never run destructive kubectl commands** (`kubectl delete`, `kubectl scale --replicas=0`, etc.) without explicit user confirmation
- **Production extra caution**: Always double-check you are targeting the correct environment before running commands, especially for `eks-prod`
- **Credentials expire**: SSO sessions and role credentials have expiration times. If commands start failing with auth errors, re-run the appropriate `eks-*` alias
