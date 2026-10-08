# platform-infra

Terraform for every AWS resource in the lab. Nothing in AWS is created by hand.

See [platform-bootstrap](https://github.com/mjbrian/platform-bootstrap) for how this repo fits with the others.

## What lives here

| Path | Purpose |
| --- | --- |
| `bootstrap/` | State bucket, GitHub OIDC provider, CI roles. Applied by hand once |
| `modules/` | Reusable building blocks, such as `vpc` and `k3s-node`. Never applied directly |
| `shared/foundation/` | The network every target sits on |
| `shared/platform/` | Shared runtime apps run on, such as clusters |
| `apps/<app>/` | Everything one application owns, such as its database and IAM role |
| `<root>/env/` | Config per target. `<target>.tfvars` holds settings and `<target>.backend.hcl` says where state lives |
| `policy/` | Conftest rules checked against every plan |
| `functions/` | Lambda code deployed by Terraform |
| `test/` | Terratest suites |

## Roots, targets, and layers

A root is a folder Terraform applies. A target is an environment and region, such as `prod-us-west-2`. Each root is written once, and each target it runs in has a pair of config files in its `env/` folder. Dev and prod differ only by those files.

Roots apply in layers. Foundation first, then platform, then apps. A root exists in a region only if it has config for that target. Roots find each other's resources by the `environment` and `layer` tags, never by reading each other's state.

To add a target, add config files to each root that should exist there, then add matching entries to the CI matrix in layer order.

## How changes ship

1. Open a pull request. CI plans every root for every target, runs fmt, validate, tflint, trivy, conftest, and Infracost, then comments each plan.
2. Merge. CI plans again and waits for approval on the `aws` environment.
3. Approve. CI applies the saved plans in layer order, lower targets first.

After Phase 3, never run `terraform apply` from a laptop, except to recover CI itself.

## Relates to

- `platform-gitops` uses values this repo outputs, such as each cluster's Elastic IP.
- The AWS k3s clusters run on nodes the platform root builds.

## Local commands

```bash
task plan ROOT=shared/foundation                    # TARGET defaults to prod-us-west-2
task plan ROOT=shared/platform TARGET=dev-us-west-2
task output ROOT=shared/platform
task plan-target TARGET=prod-us-west-2              # every root with config, in layer order
task lint
task test
```

The Taskfile pairs a target's backend and tfvars files, so never run `terraform init` or `plan` by hand.
