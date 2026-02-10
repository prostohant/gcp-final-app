# resource "google_compute_network" "custom_vpc" {
#   name                    = var.vpc_name
#   auto_create_subnetworks = false
# }

# resource "google_compute_subnetwork" "lab_subnet" {
#   name          = "${var.vpc_name}-subnet"
#   ip_cidr_range = var.vpc_ip_range
#   region        = var.region
#   network = google_compute_network.custom_vpc.id
# }

# resource "google_compute_firewall" "allow_ssh" {
#   name    = "${var.vpc_name}-allow-ssh"
#   network = google_compute_network.custom_vpc.name

#   allow {
#     protocol = "tcp"
#     ports    = ["22"]
#   }

#   source_ranges = ["0.0.0.0/0"]
#   target_tags   = ["ssh-enabled"]
# }