/*****************
 * Disk
 *****************/
resource "sakuracloud_disk" "front" {
  name = "${format("%s%02d" , var.front_disk_name , count.index+1)}"
  source_archive_name = "${var.front_archive_name}"
  ssh_key_ids = ["${sakuracloud_ssh_key.key.id}"]
  size = "${var.front_disk_size}"
  disable_pw_auth = true
  zone = "${var.zone}"
  count = "${var.front_count}"
}

/*****************
 * Server
 *****************/
resource "sakuracloud_server" "front" {
  name = "${format("%s%02d" , var.front_server_name , count.index+1)}"
  disks = ["${element(sakuracloud_disk.front.*.id , count.index)}"]
  additional_interfaces = ["${sakuracloud_switch.sw_consul.id}" , "${sakuracloud_switch.sw_front.id}"]
#  packet_filter_ids = [ "${compact(split("," , var.packet_filter_ids))}" ]
  tags = ["@virtio-net-pci","consul","nginx"]
  core = "${var.front_core}"
  memory = "${var.front_memory}"
  zone = "${var.zone}"
  count = "${var.front_count}"

  connection {
    user = "root"
    host = "${self.base_nw_ipaddress}"
    private_key = "${file("keys/id_rsa")}"
  }

  provisioner "local-exec"{
    command = "echo \"ssh -i ${path.root}/keys/id_rsa root@${self.base_nw_ipaddress}\" > ssh/${self.name}.sh; chmod +x ssh/${self.name}.sh"
  }

  provisioner "file" {
    source = "provision"
    destination = "/tmp"
  }
  provisioner "file" {
    source = "consul-template"
    destination = "/etc"
  }
  provisioner "file" {
    source = "nginx"
    destination = "/etc"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/provision/*.sh",
      "/tmp/provision/init.sh",
      "/tmp/provision/private_ip.sh eth1 \"${element(split(",",var.front_private_ip_list.consul) , count.index)}\"",
      "/tmp/provision/private_ip.sh eth2 \"${element(split(",",var.front_private_ip_list.front) , count.index)}\"",
      "/tmp/provision/consul.sh ${self.name} ${element(split(",",var.front_private_ip_list.consul) , count.index)} \"\" \"${join(" " , formatlist("-retry-join=%s",split(",",var.servers_private_ip_list.consul)))}\"",
      "sed -i -e 's/__YOUR_DOMAIN_NAME__/${var.target_domain}/g' /etc/consul-template/virtualhosts.tmpl",
      "/tmp/provision/nginx.sh"
    ]
  }
}

output front_global_ip {
  value = "${join("," , sakuracloud_server.front.*.base_nw_ipaddress)}"
}

#************************************************
# さくらのクラウドDNSを使う場合
# 例:nomad.example.com配下にエンドポイントを設ける場合
#************************************************
#resource "sakuracloud_dns" "front_dns"{
#    zone = "example.com"
#    records = {
#        name = "*.nomad"
#        type = "A"
#        value = "${sakuracloud_server.front.0.base_nw_ipaddress}"
#    }
#}


