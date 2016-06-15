resource "sakuracloud_ssh_key" "key" {
  name = "sshkey"
  public_key = "${file("${path.root}/keys/id_rsa.pub")}"
}
