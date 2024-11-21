provider "aws" {
  region = "eu-west-1"
}

terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.74.0"
    }
  }

  backend "s3" {
    bucket         = "pgr301-2024-terraform-state"
    key            = "010/terraform.tfstate"
    region         = "eu-west-1"
  }
}

# Create a new IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "lambda_exec_role_toru010"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies for Lambda logging, S3, and SQS
resource "aws_iam_role_policy" "lambda_policy" {
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ],
        Effect = "Allow",
        Resource = [
          "arn:aws:s3:::${var.bucket_name}/010/*"
        ]
      },
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Effect = "Allow",
        Resource = aws_sqs_queue.image_generation_queue.arn
      }
    ]
  })
}

# SQS Queue
resource "aws_sqs_queue" "image_generation_queue" {
  name = "image-generation-queue_010"
}

# Zip the Lambda function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "lambda_sqs.py"
  output_path = "${path.module}/lambda_sqs.zip"
}

# Create the Lambda function
resource "aws_lambda_function" "image_generation_lambda_010" {
  function_name = "image_generation_lambda_010"
  role          = aws_iam_role.lambda_role.arn  # Use the newly created IAM role
  handler       = "lambda_sqs.lambda_handler"
  runtime       = "python3.12"
  filename      = data.archive_file.lambda_zip.output_path
  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      FOLDER_NAME = "010"
    }
  }

  timeout      = 30
  memory_size  = 256
}

# SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_generation_queue.arn
  function_name    = aws_lambda_function.image_generation_lambda_010.arn
  batch_size       = 5
  enabled          = true
}
