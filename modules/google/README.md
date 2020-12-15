# Terraform GCP blobtruck module

Configures blobtrunk for migrating tf-blob service data from local backend into the Google Cloud Storage

---
## Inputs

| Name | Description | Type |  Default  | Required |
|------|-------------|------|-----------|:-----:|
| region | n/a | `string` | `"us-central1"` | no |
| zone | n/a | `string` | `"us-central1-a"` | no |
| machine_type | n/a | `string` | `"f1-micro"` | no |
| database_instance_tier | n/a | `string` | `"db-f1-micro"` | no |
| packagecloud_token | n/a | `string` | n/a | yes |
| crypto_key | The crypto key to decrypt blobs | `string` | n/a | yes |
| target_bucket | The name of the bucket where blobs should be migrated to | `string` | n/a | yes |
| sql_dump_bucket | The name of the bucket where sql dump of tf_blobs table is stored | `string` | n/a | yes |
| sql_dump_file_name | The name of sql dump file | `string` | n/a | yes |
| max_allowed_packet | n/a | `int` | `131072` | no |
| ssh_timeout | n/a | `string` | `"300s"` | no |
