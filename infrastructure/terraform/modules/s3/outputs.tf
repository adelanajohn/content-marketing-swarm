output "images_bucket_name" {
  description = "Name of the images S3 bucket"
  value       = aws_s3_bucket.images.id
}

output "images_bucket_arn" {
  description = "ARN of the images S3 bucket"
  value       = aws_s3_bucket.images.arn
}

output "frontend_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "frontend_bucket_arn" {
  description = "ARN of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend.arn
}

output "cloudfront_distribution_id" {
  description = "ID of CloudFront distribution for frontend"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "Domain name of CloudFront distribution for frontend"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "cloudfront_distribution_arn" {
  description = "ARN of CloudFront distribution for frontend"
  value       = aws_cloudfront_distribution.frontend.arn
}

output "images_cloudfront_distribution_id" {
  description = "ID of CloudFront distribution for images"
  value       = var.create_images_cdn ? aws_cloudfront_distribution.images[0].id : null
}

output "images_cloudfront_domain_name" {
  description = "Domain name of CloudFront distribution for images"
  value       = var.create_images_cdn ? aws_cloudfront_distribution.images[0].domain_name : null
}
