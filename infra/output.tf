output "sqs_queue_url" {
  description = "URL of the SQS queue for image generation"
  value       = aws_sqs_queue.image_generation_queue.id
}