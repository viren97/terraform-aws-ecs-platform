# alb

Shared HTTPS ALB (TLS 1.3 policy, HTTP→HTTPS redirect, invalid headers dropped) with a production listener and a blue/green test listener. Unmatched hosts get a 404; services attach their own host-based rules.

Usable on its own; see [`stack/`](../../stack) for how the modules are composed.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
