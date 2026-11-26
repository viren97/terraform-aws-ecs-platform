data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  build_image = var.cpu_architecture == "ARM64" ? "aws/codebuild/amazonlinux-aarch64-standard:3.0" : "aws/codebuild/amazonlinux-x86_64-standard:5.0"
  build_type  = var.cpu_architecture == "ARM64" ? "ARM_CONTAINER" : "LINUX_CONTAINER"
  account_id  = data.aws_caller_identity.current.account_id
  region      = data.aws_region.current.region
}

# ---------------------------------------------------------------- CodeBuild
resource "aws_cloudwatch_log_group" "build" {
  name              = "/codebuild/${var.name}"
  retention_in_days = 14
  tags              = var.tags
}

data "aws_iam_policy_document" "codebuild_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid       = "Logs"
    actions   = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["${aws_cloudwatch_log_group.build.arn}:*"]
  }

  statement {
    sid       = "EcrAuth"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "EcrPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
    ]
    resources = [var.ecr_repository_arn]
  }

  statement {
    sid       = "ReadLiveTaskDefinition"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"] # DescribeTaskDefinition does not support resource-level permissions
  }

  statement {
    sid       = "Artifacts"
    actions   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
    resources = ["${var.artifact_bucket_arn}/*"]
  }
}

resource "aws_iam_role" "codebuild" {
  name_prefix        = "${var.name}-cb-"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "build"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "this" {
  name          = var.name
  description   = "Test, build and push ${var.name}, then render deploy inputs"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 30
  tags          = var.tags

  environment {
    compute_type    = var.build_compute_type
    image           = local.build_image
    type            = local.build_type
    privileged_mode = true

    environment_variable {
      name  = "REPOSITORY_URL"
      value = var.ecr_repository_url
    }
    environment_variable {
      name  = "TASK_FAMILY"
      value = var.task_definition_family
    }
    environment_variable {
      name  = "CONTAINER_NAME"
      value = var.container_name
    }
    environment_variable {
      name  = "CONTAINER_PORT"
      value = tostring(var.container_port)
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = templatefile("${path.module}/templates/buildspec.yml.tftpl", { test_command = var.test_command })
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_CUSTOM_CACHE"]
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }
}

# ---------------------------------------------------------------- CodePipeline
data "aws_iam_policy_document" "codepipeline_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid = "Artifacts"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:GetBucketVersioning",
    ]
    resources = [var.artifact_bucket_arn, "${var.artifact_bucket_arn}/*"]
  }

  statement {
    sid       = "Source"
    actions   = ["codestar-connections:UseConnection", "codeconnections:UseConnection"]
    resources = [var.connection_arn]
  }

  statement {
    sid       = "Build"
    actions   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
    resources = [aws_codebuild_project.this.arn]
  }

  statement {
    sid = "Deploy"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetDeploymentConfig",
    ]
    resources = [
      "arn:aws:codedeploy:${local.region}:${local.account_id}:application:${var.codedeploy_app_name}",
      "arn:aws:codedeploy:${local.region}:${local.account_id}:deploymentgroup:${var.codedeploy_app_name}/${var.codedeploy_deployment_group_name}",
      "arn:aws:codedeploy:${local.region}:${local.account_id}:deploymentconfig:*",
    ]
  }

  statement {
    sid       = "RegisterTaskDefinition"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"] # RegisterTaskDefinition does not support resource-level permissions
  }

  statement {
    sid       = "PassTaskRoles"
    actions   = ["iam:PassRole"]
    resources = var.task_role_arns
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = length(var.approval_topic_arns) > 0 ? [1] : []
    content {
      sid       = "ApprovalNotifications"
      actions   = ["sns:Publish"]
      resources = var.approval_topic_arns
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name_prefix        = "${var.name}-cp-"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "codepipeline" {
  name   = "pipeline"
  role   = aws_iam_role.codepipeline.id
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_codepipeline" "this" {
  name           = var.name
  role_arn       = aws_iam_role.codepipeline.arn
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  tags           = var.tags

  artifact_store {
    type     = "S3"
    location = var.artifact_bucket_name

    dynamic "encryption_key" {
      for_each = var.kms_key_arn == null ? [] : [var.kms_key_arn]
      content {
        id   = encryption_key.value
        type = "KMS"
      }
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["Source"]
      configuration = {
        ConnectionArn        = var.connection_arn
        FullRepositoryId     = var.repository
        BranchName           = var.branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "TestBuildPush"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["Source"]
      output_artifacts = ["Build"]
      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  dynamic "stage" {
    for_each = var.require_manual_approval ? [1] : []
    content {
      name = "Approve"
      action {
        name     = "ReleaseApproval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
        configuration = length(var.approval_topic_arns) > 0 ? {
          NotificationArn = var.approval_topic_arns[0]
          CustomData      = "Approve ${var.name} for release"
        } : null
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name            = "CanaryBlueGreen"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CodeDeployToECS"
      version         = "1"
      input_artifacts = ["Build"]
      configuration = {
        ApplicationName                = var.codedeploy_app_name
        DeploymentGroupName            = var.codedeploy_deployment_group_name
        TaskDefinitionTemplateArtifact = "Build"
        TaskDefinitionTemplatePath     = "taskdef.json"
        AppSpecTemplateArtifact        = "Build"
        AppSpecTemplatePath            = "appspec.yaml"
        Image1ArtifactName             = "Build"
        Image1ContainerName            = "IMAGE1_NAME"
      }
    }
  }
}
