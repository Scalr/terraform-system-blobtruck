resource "google_compute_network" "network" {
  name                    = "blobtruck-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "blobtruck-network-${var.region}"
  ip_cidr_range = "10.10.10.0/24"
  region        = var.region
  network       = google_compute_network.network.self_link
}

resource "google_compute_firewall" "block_incoming_connections" {
  name        = "blobtruck-block-incoming-connections"
  network     = google_compute_network.network.self_link
  description = "Block all incoming connections to the VPC network"
  direction   = "INGRESS"
  priority    = 1000

  deny {
    protocol = "icmp"
  }
  deny {
    protocol = "tcp"
  }
  deny {
    protocol = "udp"
  }
}

resource "google_compute_firewall" "allow_incoming_ssh" {
  name        = "blobtruck-allow-incoming-ssh"
  network     = google_compute_network.network.self_link
  description = "Allow incoming SSH connections to the blobtruck node"
  priority    = 999

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  target_tags = [local.node_firewall_tag]
}
