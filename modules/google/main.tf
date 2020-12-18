provider "google" {
  region = var.region
  zone = var.zone
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "random_password" "password" {
  length = 16
  special = true
  override_special = "_%@"
}

locals {
  ssh_user = "gce-blobtruck-user"
  ssh_port = 22
  ssh_timeout = var.ssh_timeout
  ssh_private_key = tls_private_key.ssh.private_key_pem
  ssh_public_key = tls_private_key.ssh.public_key_openssh

  db_user = "blobtruck"
  db_pass = random_password.password.result

  node_firewall_tag = "blobtruck-node"

  dump_uri = "gs://${var.sql_dump_bucket}/${var.sql_dump_file_name}"
}

data "google_project" "project" {}

data "google_storage_bucket_object" "dump" {
  name = var.sql_dump_file_name
  bucket = var.sql_dump_bucket
}

resource "google_compute_address" "node_address" {
  name = "blobtruck-node-address"
}

resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "mysql" {
  name = "blobtruck-mysql-instance-${random_id.db_name_suffix.hex}"
  database_version = "MYSQL_5_7"

  settings {
    tier = var.database_instance_tier

    ip_configuration {
      authorized_networks {
        value = google_compute_address.node_address.address
      }
    }

    database_flags {
      name  = "max_allowed_packet"
      value = var.max_allowed_packet
    }
  }

  deletion_protection = false
}

resource "google_sql_database" "database" {
  name = "default"
  instance = google_sql_database_instance.mysql.name
}

resource "google_sql_user" "users" {
  name = local.db_user
  instance = google_sql_database_instance.mysql.name
  host = google_compute_address.node_address.address
  password = local.db_pass
}

resource "google_storage_bucket_iam_binding" "admins" {
  bucket = var.sql_dump_bucket
  role = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${google_sql_database_instance.mysql.service_account_email_address}"]
  depends_on = [
    google_sql_database_instance.mysql
  ]
}

data "template_file" "blobtruck_yml" {
  template = file("${path.module}/configs/blobtruck.yml.tpl")

  vars = {
    db_host = google_sql_database_instance.mysql.public_ip_address
    db_port = 3306
    db_user = local.db_user
    db_pass = local.db_pass
    db_name = google_sql_database.database.name
    crypto_key = var.crypto_key
    bucket_id = var.target_bucket
  }
}

resource "google_compute_instance" "node" {
  name = "blobtruck-node"
  machine_type = var.machine_type

  boot_disk {
    initialize_params {
      image = "centos-7"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.subnet.self_link
    access_config {
      nat_ip = google_compute_address.node_address.address
    }
  }

  service_account {
    scopes = [
      "cloud-platform",
    ]
  }
  allow_stopping_for_update = true

  metadata = {
    ssh-keys = "${local.ssh_user}:${local.ssh_public_key}"
  }

  tags = [
    local.node_firewall_tag
  ]

  timeouts {
    create = var.provisioning_timeout
    update = var.provisioning_timeout
  }

  depends_on = [
    google_storage_bucket_iam_binding.admins
  ]

  connection {
    host = google_compute_address.node_address.address
    type = "ssh"
    user = local.ssh_user
    timeout = local.ssh_timeout
    private_key = local.ssh_private_key
  }

  provisioner "file" {
    content = data.template_file.blobtruck_yml.rendered
    destination = "/var/tmp/blobtruck.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -ex",
      "sudo curl -s https://${var.packagecloud_token}:@packagecloud.io/install/repositories/${var.packagecloud_repo}/script.rpm.sh | sudo bash",
      "sudo yum --assumeyes install -q blobtruck",
      "sudo mv /var/tmp/blobtruck.yml /etc/blobtruck/blobtruck.yml",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "set -ex",
      "url=`gcloud sql import sql ${google_sql_database_instance.mysql.name} ${local.dump_uri} --database=default --async --quiet`",
      "operation=`echo $url | egrep '[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}' -o`",
      "gcloud beta sql operations wait --project ${data.google_project.project.project_id}  $operation --quiet --timeout=${var.sql_import_wait_timeout}",
    ]
  }
}

resource "null_resource" "run_blobtruck" {
  connection {
    host = google_compute_address.node_address.address
    type = "ssh"
    user = local.ssh_user
    timeout = local.ssh_timeout
    private_key = local.ssh_private_key
  }

  provisioner "remote-exec" {
    inline = [
      "blobtruck",
    ]
  }

  depends_on = [
    google_compute_instance.node
  ]
}
