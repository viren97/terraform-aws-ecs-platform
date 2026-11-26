# ecs-service

One Fargate service with everything it needs to release safely: blue/green target groups and host-based listener rules, least-privilege execution and task roles, secrets injected from Secrets Manager, target-tracking autoscaling, and a CodeDeploy canary deployment group that rolls back automatically on 5xx-rate or p99-latency alarms.

Usable on its own; see [`stack/`](../../stack) for how the modules are composed.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
