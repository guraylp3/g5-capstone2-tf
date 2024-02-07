terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "s3" {
    bucket = "g5-capstone2-bucket-tf"
    key    = "state/remote-state"
    region = "us-west-2"
  }
}

# Configure the AWS Provider
provider "aws" {
    region="us-west-2"
}

resource "aws_ecr_repository" "g5_capstone2_ecr_tf" {
  name = "g5-capstone2-ecr-tf" # Naming my repository
}
resource "aws_ecs_cluster" "g5_ecs_capstone2_tf" {
  name = "g5-ecs-capstone2-tf" # Naming the cluster
}
resource "aws_ecs_task_definition" "g5_taskdef_capstone2_tf" {
  family                   = "g5-taskdef-capstone2-tf" # Naming our first task
  container_definitions    = <<DEFINITION
  [
    {
      "name": "g5-taskdef-capstone2-tf",
      "image": "${aws_ecr_repository.g5_capstone2_ecr_tf.repository_url}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 3000,
          "hostPort": 3000
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = "arn:aws:iam::962804699607:role/ecsTaskExecutionRole"
}

resource "aws_ecs_service" "g5_service_capstone2_tf" {
  name            = "g5-service-capstone2-tf"                             # Naming our first service
  cluster         = "${aws_ecs_cluster.g5_ecs_capstone2_tf.id}"             # Referencing our created Cluster
  task_definition = "${aws_ecs_task_definition.g5_taskdef_capstone2_tf.arn}" # Referencing the task our service will spin up
  launch_type     = "FARGATE"
  desired_count   = 1 # Setting the number of containers we want deployed to 3
  
  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true # Providing our containers with public IPs
  }
}

# Providing a reference to our default VPC
resource "aws_default_vpc" "default_vpc" {
}


# Providing a reference to our default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-west-2a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-west-2b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "us-west-2c"
}

// CodeBuild Role
resource "aws_iam_role_policy" "g5_codebuild_policy_tf" {
  name   = "g5-codebuild-policy-tf"
  role   = aws_iam_role.g5_codebuild_role_tf.id
  policy = data.aws_iam_policy_document.codebuild_policy.json
}
 
resource "aws_iam_role" "g5_codebuild_role_tf" {
  name               = "g5-codebuild-role-tf"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role.json
}
 
data "aws_iam_policy_document" "codebuild_policy" {
  statement {
    effect = "Allow"
 
    actions = [
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
      "logs:PutLogEvents",
      "s3:*"
    ]
 
    resources = ["*"]
  }
 
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = ["arn:aws:codestar-connections:us-west-2:962804699607:connection/5bbfbc52-4a3e-4124-a0ee-daf366f4ec2b"]
  }
 
  statement {
    effect = "Allow"
 
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
      "codebuild:CreateReportGroup",
      "codebuild:CreateReport",
      "codebuild:UpdateReport",
      "codebuild:BatchPutTestCases",
      "codebuild:BatchPutCodeCoverages",
      "ecr:CompleteLayerUpload",
      "ecr:GetAuthorizationToken",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage"
    ]
 
    resources = ["*"]
  }
}
 
data "aws_iam_policy_document" "codebuild_assume_role" {
  statement {
    effect = "Allow"
 
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
 
    actions = ["sts:AssumeRole"]
  }
}




resource "aws_codebuild_project" "g5_capstone2_codebuild_tf" {
  name          = "g5-capstone2-codebuild-tf"
  description   = "g5-capstone2-codebuild-tf"
  build_timeout = 5
  service_role  = aws_iam_role.g5_codebuild_role_tf.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type     = "NO_CACHE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }
  
  logs_config {
    cloudwatch_logs {
    }
  }

  source {
    type            = "GITHUB"
    location        = "https://github.com/guraylp3/g5-capstone2.git"
    git_clone_depth = 1
  }

  source_version = "main"
}

# CodePipeline Role 
resource "aws_iam_role_policy" "g5_codepipeline_policy_tf" {
  name   = "g5-codepipeline-policy-tf"
  role   = aws_iam_role.g5_codepipeline_role_tf.id
  policy = data.aws_iam_policy_document.codepipeline_policy.json
}
 
resource "aws_iam_role" "g5_codepipeline_role_tf" {
  name               = "g5-codepipeline-role-tf"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}
 
data "aws_iam_policy_document" "codepipeline_policy" {
  statement {
    effect = "Allow"
 
    actions = [
      "s3:*",
      "logs:CreateLogStream",
    ]
 
    resources = [
    "*"
    //  "arn:aws:s3:::codepipeline-us-west-2-627007557336"
    ]
  }
 
  statement {
    effect    = "Allow"
    actions   = ["codestar-connections:UseConnection"]
    resources = ["arn:aws:codestar-connections:us-west-2:962804699607:connection/5bbfbc52-4a3e-4124-a0ee-daf366f4ec2b"]
  }
 
  statement {
    effect = "Allow"
 
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild",
    ]
 
    resources = ["*"]
  }
}
 
data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"
 
    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
 
    actions = ["sts:AssumeRole"]
  }
}


resource "aws_codepipeline" "g5_codepipeline_capstone2_tf" {
  name     = "g5-codepipeline-capstone2-tf"
  role_arn = aws_iam_role.g5_codepipeline_role_tf.arn
  
  artifact_store {
    location = "codepipeline-us-west-2-627007557336"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      region           = "us-west-2"
      version          = "1"
      output_artifacts = ["g5-capstone2-source-artifact-tf"]

      configuration = {
        ConnectionArn    = "arn:aws:codestar-connections:us-west-2:962804699607:connection/5bbfbc52-4a3e-4124-a0ee-daf366f4ec2b"
        FullRepositoryId = "guraylp3/g5-capstone2"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["g5-capstone2-source-artifact-tf"]
      output_artifacts = ["g5-capstone2-build-artifact-tf"]
      region           = "us-west-2"
      version          = "1"

      configuration = {
        ProjectName = "g5-capstone2-codebuild-tf"
      }
    }
  }
/*
  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "CloudFormation"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        ActionMode     = "REPLACE_ON_FAILURE"
        Capabilities   = "CAPABILITY_AUTO_EXPAND,CAPABILITY_IAM"
        OutputFileName = "CreateStackOutput.json"
        StackName      = "MyStack"
        TemplatePath   = "build_output::sam-templated.yaml"
      }
    }
  }
  */
}

/* // TODO: Do later if time
resource "aws_codestarconnections_connection" "g5_capstone2_codestar_tf" {
  name          = "g5-capstone2-codestar-tf"
  provider_type = "GitHub"
}
*/
