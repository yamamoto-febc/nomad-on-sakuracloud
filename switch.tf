resource sakuracloud_switch "sw_front" {
    name = "sw_front"
    zone = "${var.zone}"
}
resource sakuracloud_switch "sw_nomad" {
    name = "sw_nomad"
    zone = "${var.zone}"
}
resource sakuracloud_switch "sw_consul" {
    name = "sw_consul"
    zone = "${var.zone}"
}
