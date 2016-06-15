/*****************
 * Disk
 *****************/
resource "sakuracloud_disk" "agents" {
  name = "${format("%s%02d" , var.agents_disk_name , count.index+1)}"
  source_archive_name = "${var.agents_archive_name}"
  ssh_key_ids = ["${sakuracloud_ssh_key.key.id}"]
  size = "${var.agents_disk_size}"
  disable_pw_auth = true
  zone = "${var.zone}"
  count = "${var.agents_count}"
}

/*****************
 * Server
 *****************/
resource "sakuracloud_server" "agents" {
  name = "${format("%s%02d" , var.agents_server_name , count.index+1)}"
  disks = ["${element(sakuracloud_disk.agents.*.id , count.index)}"]
  additional_interfaces = ["${sakuracloud_switch.sw_consul.id}" , "${sakuracloud_switch.sw_nomad.id}" , "${sakuracloud_switch.sw_front.id}"]
#  packet_filter_ids = [ "${compact(split("," , var.packet_filter_ids))}" ]
  tags = ["@virtio-net-pci","consul","nomad"]
  core = "${var.agents_core}"
  memory = "${var.agents_memory}"
  zone = "${var.zone}"
  count = "${var.agents_count}"

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
      "/tmp/provision/private_ip.sh eth1 \"${element(split(",",var.agents_private_ip_list.consul) , count.index)}\"",
      "/tmp/provision/private_ip.sh eth2 \"${element(split(",",var.agents_private_ip_list.nomad) , count.index)}\"",
      "/tmp/provision/private_ip.sh eth3 \"${element(split(",",var.agents_private_ip_list.front) , count.index)}\"",
      "/tmp/provision/consul.sh ${self.name} ${element(split(",",var.agents_private_ip_list.consul) , count.index)} \"\" \"${join(" " , formatlist("-retry-join=%s",split(",",var.servers_private_ip_list.consul)))}\"",
      "/tmp/provision/docker.sh",
      "/tmp/provision/nomad.sh ${self.name} ${element(split(",",var.agents_private_ip_list.nomad) , count.index)} \"\" ''"
    ]
  }
}
