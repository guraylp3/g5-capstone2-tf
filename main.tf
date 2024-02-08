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
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:GetDeployment",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:RegisterApplicationRevision",
      "ecs:*",
      "iam:PassRole"
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

   stage {
       name = "Deploy"
 
       action {
           category         = "Deploy"
           configuration    = {
               "ClusterName" = "${aws_ecs_cluster.g5_ecs_capstone2_tf.name}"
               "FileName"    = "imagedefinitions.json"
               "ServiceName" = "${aws_ecs_service.g5_service_capstone2_tf.name}"
           }
           input_artifacts  = [
               "g5-capstone2-build-artifact-tf",
           ]
           name             = "g5-capstone2-deploy-tf"
           output_artifacts = []
           owner            = "AWS"
           provider         = "ECS"
           region           = "us-west-2"
           run_order        = 1
           version          = "1"
       }
   }
  }

// Infrastrucutre for Application API
// Import
/*resource "aws_api_gateway_rest_api" "g5_capstone2_api_gateway_rest_api" {
    api_key_source               = "HEADER"
    arn                          = "arn:aws:apigateway:us-west-2::/restapis/igqma0tvx3"
    binary_media_types           = []
    created_date                 = "2024-02-05T21:05:58Z"
    disable_execute_api_endpoint = false
    execution_arn                = "arn:aws:execute-api:us-west-2:962804699607:igqma0tvx3"
    id                           = "igqma0tvx3"
    minimum_compression_size     = -1
    name                         = "g5-capstone2-api"
    put_rest_api_mode            = "overwrite"
    root_resource_id             = "bj0yt1sloc"
    tags                         = {}
    tags_all                     = {}

    endpoint_configuration {
        types            = [
            "REGIONAL",
        ]
        vpc_endpoint_ids = []
    }
}*/

resource "aws_api_gateway_rest_api" "g5_capstone2_api_gateway_rest_api_tf" {
    api_key_source               = "HEADER"
    disable_execute_api_endpoint = false
    name                         = "g5-capstone2-api-tf"
    put_rest_api_mode            = "overwrite"
    tags                         = {}
    tags_all                     = {}

    endpoint_configuration {
        types            = [
            "REGIONAL",
        ]
    }
}

resource aws_api_gateway_resource "g5_capstone2_api_gateway_resource_tf" {
    path_part   = "get-person"
    parent_id   = "${aws_api_gateway_rest_api.g5_capstone2_api_gateway_rest_api_tf.root_resource_id}"
    rest_api_id = "${aws_api_gateway_rest_api.g5_capstone2_api_gateway_rest_api_tf.id}"
}

resource "aws_api_gateway_method" "g5_capstone2_api_gateway_method_tf" {
    api_key_required     = false
    authorization        = "NONE"
    authorization_scopes = []
    http_method          = "GET"
    resource_id          = "${aws_api_gateway_resource.g5_capstone2_api_gateway_resource_tf.id}"
    rest_api_id          = "${aws_api_gateway_rest_api.g5_capstone2_api_gateway_rest_api_tf.id}"
}

resource "aws_api_gateway_integration" "g5_capstone2_api_gateway_integration_tf" {
    content_handling        = "CONVERT_TO_TEXT"
    http_method             = "GET"
    integration_http_method = "POST" // From docs: Lambda function can only be invoked via post
    resource_id             = "${aws_api_gateway_resource.g5_capstone2_api_gateway_resource_tf.id}"
    rest_api_id             = "${aws_api_gateway_rest_api.g5_capstone2_api_gateway_rest_api_tf.id}"
    timeout_milliseconds    = 29000
    type                    = "AWS"
    uri                     = "arn:aws:apigateway:us-west-2:lambda:path/2015-03-31/functions/arn:aws:lambda:us-west-2:962804699607:function:g5-get-person/invocations"
}

resource "aws_api_gateway_integration_response" "g5_capstone2_api_gateway_integration_response_tf" {
    http_method         = "GET"
    resource_id         = "${aws_api_gateway_resource.g5_capstone2_api_gateway_resource_tf.id}"
    rest_api_id         = "${aws_api_gateway_rest_api.g5_capstone2_api_gateway_rest_api_tf.id}"
    status_code         = "200"
    response_templates  = {
        "application/json" = ""
    }
    depends_on = [
      aws_api_gateway_integration.g5_capstone2_api_gateway_integration_tf
    ]
}

resource "aws_api_gateway_method_response" "g5_capstone2_api_gateway_method_response_tf" {
    http_method         = "GET"
    resource_id         = "${aws_api_gateway_resource.g5_capstone2_api_gateway_resource_tf.id}"
    response_models     = {
        "application/json" = "Empty"
    }
    rest_api_id         = "${aws_api_gateway_rest_api.g5_capstone2_api_gateway_rest_api_tf.id}"
    status_code         = "200"
}
  


/* // TODO: Do later if time
resource "aws_codestarconnections_connection" "g5_capstone2_codestar_tf" {
  name          = "g5-capstone2-codestar-tf"
  provider_type = "GitHub"
}
*/
