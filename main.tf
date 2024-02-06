terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
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
