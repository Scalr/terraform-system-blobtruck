variable "region" {
  default = "us-central1"
}

variable "zone" {
  default = "us-central1-a"
}

variable "machine_type" {
  default = "n1-standard-2"
}

variable "database_instance_tier" {
  default = "db-n1-standard-2"
}

variable "packagecloud_token" {
}

variable "packagecloud_repo" {
  default = "scalr/scalr-server-ee"
}

variable "crypto_key" {
  description = "The crypto key to decrypt blobs"
}
variable "target_bucket" {
  description = "The name of the bucket where blobs should be migrated to"
}

variable "sql_dump_bucket" {
  type = string
  description = "The name of the bucket where sql dump of tf_blobs table is stored"
}

variable "sql_dump_file_name" {
  type = string
  description = "The name of sql dump file"
}

variable "max_allowed_packet" {
  default = "134217728"
  description = "The maximum size of one packet in bytes, defaults to 128Mb"
}

variable "ssh_timeout" {
  default = "300s"
}