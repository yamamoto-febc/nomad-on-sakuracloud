/*****************
 * Disk
 *****************/
resource "sakuracloud_disk" "servers" {
  name = "${format("%s%02d" , var.servers_disk_name , count.index+1)}"
  source_archive_name = "${var.servers_archive_name}"
  ssh_key_ids = ["${sakuracloud_ssh_key.key.id}"]
  size = "${var.servers_disk_size}"
  disable_pw_auth = true
  zone = "${var.zone}"
  count = "${var.servers_count}"
}

/*****************
 * Server
 *****************/
resource "sakuracloud_server" "servers" {
  name = "${format("%s%02d" , var.servers_server_name , count.index+1)}"
  disks = ["${element(sakuracloud_disk.servers.*.id , count.index)}"]
  additional_interfaces = ["${sakuracloud_switch.sw_consul.id}" , "${sakuracloud_switch.sw_nomad.id}"]
#  packet_filter_ids = [ "${compact(split("," , var.packet_filter_ids))}" ]
  tags = ["@virtio-net-pci","consul","nomad"]
  core = "${var.servers_core}"
  memory = "${var.servers_memory}"
  zone = "${var.zone}"
  count = "${var.servers_count}"

  connection {
    user = "root"
    host = "${self.base_nw_ipaddress}"
    private_key = "${file("${path.root}/keys/id_rsa")}"
  }

  provisioner "local-exec"{
    command = "echo \"ssh -i ${path.root}/keys/id_rsa root@${self.base_nw_ipaddress}\" > ssh/${self.name}.sh; chmod +x ssh/${self.name}.sh"
  }

  provisioner "file" {
    source = "${path.root}/provision"
    destination = "/tmp"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/provision/*.sh",
      "/tmp/provision/init.sh",
      "/tmp/provision/private_ip.sh eth1 \"${element(split(",",var.servers_private_ip_list.consul) , count.index)}\"",
      "/tmp/provision/private_ip.sh eth2 \"${element(split(",",var.servers_private_ip_list.nomad) , count.index)}\"",
      "/tmp/provision/consul.sh ${self.name} ${element(split(",",var.servers_private_ip_list.consul) , count.index)} ${var.servers_count} \"${join(" " , formatlist("-retry-join=%s",split(",",var.servers_private_ip_list.consul)))}\" 1",
      "/tmp/provision/docker.sh",
      "/tmp/provision/nomad.sh ${self.name} ${element(split(",",var.servers_private_ip_list.nomad) , count.index)} ${var.servers_count} '${join("," , formatlist("%q",split(",",var.servers_private_ip_list.nomad)))}' 1"
    ]
  }

  provisioner "file" {
    source = "${path.root}/nomad_sample"
    destination = "/root"
  }
}
