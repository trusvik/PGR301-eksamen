variable "bucket_name" {
  description = "S3 Bucket to store images"
  type        = string
  default = "pgr301-couch-explorers"
}

variable "alarm_email" {
  default = "tobias.r.rusvik@gmail.com"
  type = string
}