# network

VPC across 2-4 AZs with three tiers: public (ALB, NAT), private (ECS tasks, MSK) and isolated data subnets (RDS, ElastiCache) with no internet route. Per-AZ or single NAT, S3 gateway endpoint, optional flow logs.

Usable on its own; see [`stack/`](../../stack) for how the modules are composed.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
