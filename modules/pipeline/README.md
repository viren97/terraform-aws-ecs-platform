# pipeline

CodePipeline (V2) per service: GitHub source via CodeConnections → CodeBuild (tests, image build on Graviton, push to ECR, render taskdef.json and appspec.yaml from the live task definition) → optional manual approval → CodeDeploy canary blue/green. Service repos need only a Dockerfile.

Usable on its own; see [`stack/`](../../stack) for how the modules are composed.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
