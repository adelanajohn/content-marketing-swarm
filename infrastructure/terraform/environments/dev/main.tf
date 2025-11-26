terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Uncomment and configure for remote state
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "content-marketing-swarm/dev/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "aws" {
  region = var.aws_region
}

locals {
  project_name = "content-marketing-swarm"
  environment  = "dev"
  
  availability_zones = [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]
}

module "vpc" {
  source = "../../modules/vpc"

  project_name       = local.project_name
  environment        = local.environment
  vpc_cidr           = "10.0.0.0/16"
  availability_zones = local.availability_zones
}

module "s3" {
  source = "../../modules/s3"

  project_name         = local.project_name
  environment          = local.environment
  image_retention_days = 365  # Must be greater than transition days (90)
}

module "rds" {
  source = "../../modules/rds"

  project_name            = local.project_name
  environment             = local.environment
  vpc_id                  = module.vpc.vpc_id
  private_subnet_ids      = module.vpc.private_subnet_ids
  security_group_ids      = []  # Will be populated after ECS security group is created

  database_name           = "contentmarketing"
  master_username         = "dbadmin"
  master_password         = var.db_master_password

  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  multi_az                = false
  backup_retention_period = 7
  skip_final_snapshot     = true
  create_read_replica     = false
}

# Create Secrets Manager secret for database password
resource "aws_secretsmanager_secret" "db_password" {
  name        = "${local.project_name}-${local.environment}-db-password"
  description = "Database password for ${local.project_name} ${local.environment}"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_master_password
}

module "iam" {
  source = "../../modules/iam"

  project_name      = local.project_name
  environment       = local.environment
  images_bucket_arn = module.s3.images_bucket_arn
}

module "ecs" {
  source = "../../modules/ecs"

  project_name        = local.project_name
  environment         = local.environment
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  private_subnet_ids  = module.vpc.private_subnet_ids
  container_port      = 8000
  health_check_path   = "/health"
  s3_bucket_arn       = module.s3.images_bucket_arn

  # Database configuration
  database_host                = module.rds.db_instance_address
  database_port                = 5432
  database_name                = "contentmarketing"
  database_username            = "dbadmin"
  database_password_secret_arn = aws_secretsmanager_secret.db_password.arn
  
  # S3 bucket name
  s3_bucket_name = module.s3.images_bucket_name

  # Backend image (placeholder - will be updated after building)
  backend_image = "${var.aws_region == "us-east-1" ? "298717586028.dkr.ecr.us-east-1" : "298717586028.dkr.ecr.${var.aws_region}"}.amazonaws.com/content-marketing-swarm-backend:latest"

  # AWS configuration
  aws_region = var.aws_region

  # Custom domain configuration (optional)
  root_domain_name         = var.root_domain_name
  domain_name              = var.domain_name
  hosted_zone_id           = var.hosted_zone_id
  existing_certificate_arn = var.existing_certificate_arn
  enable_https             = var.enable_https

  # Scaling configuration
  desired_count = 2
  min_capacity  = 2
  max_capacity  = 10

  enable_deletion_protection = false
  enable_ecs_exec           = true
}
