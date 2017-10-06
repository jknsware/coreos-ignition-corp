```# Variable Definition
variable "instance_count" {default = 1} # Define the number of instances
# Configure the VMware vSphere Provider. ENV Variables set for Username and Passwd.
provider "vsphere" {
 user           = "username"
 password       = "password"
 vsphere_server = "esxi server"
 allow_unverified_ssl = true

 # Do not uncomment the following version constraints, we're using a hacked version of the plugin. See README.hacked_version_of_vsphere_plugin.txt
 #version = "~> 0.2.2"
 #version = "0.2.1"
 #version = "0.2.2"
 #version = "0.3.0"
 #version = "0.4.0"
 #version = "0.4.1"
 # Need to test any releases >0.4.1
}
provider "ignition" {
  version = "1.0.0"
}
variable "provider" {
  # vmw = VMware
  default = "vmw"
}
variable "environment" {
  # Sandbox = sndbox
  default = "sndbox"
}
variable "server_role" {
  # Build = bld
  default = "bld"
}
data "ignition_config" "node" {
  count = "${var.instance_count}"
  users = [
    "${data.ignition_user.core.id}",
  ]
  files = [
    #"${data.ignition_file.max-user-watches.id}",
    "${data.ignition_file.node_hostname.*.id[count.index]}",
    #"${data.ignition_file.kubelet-env.id}",
  ]
/*  systemd = [
    "${data.ignition_systemd_unit.docker.id}",
    #"${data.ignition_systemd_unit.locksmithd.id}",
    #"${data.ignition_systemd_unit.kubelet.id}",
    #"${data.ignition_systemd_unit.kubelet-env.id}",
    #"${data.ignition_systemd_unit.bootkube.id}",
    #"${data.ignition_systemd_unit.tectonic.id}",
  ]*/
  networkd = [
    #"${data.ignition_networkd_unit.vmnetwork_static.*.id[count.index]}",
    "${data.ignition_networkd_unit.vmnetwork_dhcp.*.id[count.index]}",
  ]
}
data "ignition_user" "core" {
  name                = "core"
  #ssh_authorized_keys = ["${var.core_public_keys}"]
  ssh_authorized_keys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDL60z9GtLASUc1G31CjrBdxjhvVHx6yNxNeYC7hKJlKgUp8L7w3+bJnQS0aPMsg3bS+ozuG4hU5LRjZa6egZdwSwz649UNv/749FuUFOkNdYGAtYzYzHfMWpwDPAWuaKHJzcQWforgGpscyU/Pk1T/+WEBji6MwKp/BTsjB1FblsmKOqcopETbOL+hTm6kdZUP0Kdg9vLBg/l9wRnHw8O7ZOOTv7zLTZfKqMpJ8f0kO6bxd+HVYz9Uig0RL0MWxioyhK2/frKtD2XWBSg1tmiO8fxl54HAZzkc/Pmkc2H9EZMirbw3E+qdoUKNTVuVqB+9Vs1VJnfzbLtvAK5ee1Tt msoares@MSOARES.local"]
}
/*data "ignition_networkd_unit" "vmnetwork_static" {
  count = "${var.instance_count}"
  name  = "00-ens192.network"
  content = <<EOF
  [Match]
  Name=ens192
  [Network]
  DNS=8.8.8.8
  Address=172.16.0.8/24
  Gateway=172.16.0.1
EOF
}*/
data "ignition_networkd_unit" "vmnetwork_dhcp" {
  count = "${var.instance_count}"
  name  = "00-ens192.network"
  content = <<EOF
  [Match]
  Name=ens192
  [Network]
  DHCP=yes
EOF
}
data "ignition_file" "node_hostname" {
  count      = "${var.instance_count}"
  path       = "/etc/hostname"
  mode       = 0644
  filesystem = "root"
  content {
    #content = "${var.hostname["${count.index}"]}"
    content = "tf-${ var.provider }-${ var.environment }-${ var.server_role }-${format("%02d", count.index+1)}"
  }
}
/*data "ignition_systemd_unit" "docker" {
  name   = "docker.service"
  enable = true
  dropin = [
    {
      name    = "10-dockeropts.conf"
      content = "[Service]\nEnvironment=\"DOCKER_OPTS=--log-opt max-size=50m --log-opt max-file=3\"\n"
    },
  ]
}*/
/*variable "tectonic_vmware_etcd_hostnames" {
  type = "map"
  description = <<EOF
  Terraform map of etcd node(s) Hostnames, Example:
  tectonic_vmware_etcd_hostnames = {
  "0" = "mycluster-etcd-0"
  "1" = "mycluster-etcd-1"
  "2" = "mycluster-etcd-2"
}
EOF
}*/
# Define the VM resource
resource "vsphere_virtual_machine" "node" {
 count = "${var.instance_count}"
 name   = "tf-${ var.provider }-${ var.environment }-${ var.server_role }-${format("%02d", count.index+1)}"
 datacenter = "AUS-TEST-DataCenter"
 cluster = "AUS-TEST-CLSTR"
 vcpu   = 2
 memory = 2048
 folder = "TF_folder"
 #domain = "blah.com"
  network_interface {
    #label = "${var.vm_network_label}"
    label = "1-SRV"
  }
  disk {
    #datastore = "${var.vm_disk_datastore}"
    datastore = "vmh1-local"
    #template  = "${var.vm_disk_template_folder}/${var.vm_disk_template}"
    # Ignition Issue (waiting for the fix to merge into the Stable channel):
    #  https://www.bountysource.com/issues/38632084-ignition-not-using-guestinfo-coreos-config-data-on-esxi
    #  https://github.com/coreos/ignition/pull/384/commits
    #template = "TF_folder/coreos-1465.8.0-ova-stable-tmpl"
          # Ignition v0.17.2 (ofvEnv (Ignition) for VMware is not working.)
    #template = "TF_folder/coreos-1520.4.0-ova-beta-tmpl"
          # Ignition v0.17.2 (ofvEnv (Ignition) for VMware is not working.)
    #template = "TF_folder/coreos-1548.0.0-ova-alpha-tmpl"
          # Ignition v0.19.0 (ofvEnv (Ignition) for VMware IS WORKING.)
    template = "TF_folder/coreos-1465.8.0-stable-10GB-tmpl"
    type      = "thin"
  }
  connection {
    type        = "ssh"
    user        = "core"
    #private_key = "${file(var.private_key != "" ? pathexpand(var.private_key) : "/dev/null")}
    private_key = "${file("~/Git/kraken/kraken/terraform/VMware_Practice/coreos/coreos_tmp")}"
  }
  provisioner "file" {
    #content     = "${var.kubeconfig}"
    content = "MY_TEST_CONTENT"
    #destination = "$HOME/my_test_file"
    destination = "my_test_file"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mv /home/core/my_test_file /etc/",
    ]
  }
 disk {
  size = "5"
   #name = "tf-${ var.provider }-${ var.environment }-${ var.server_role }-${format("%02d", count.index+1)}"
   name = "coreos-1465.8.0-stable-10GB-tmpl"
   datastore = "vmh1-local"
   type ="thin"
 }
/*# Define the Networking settings for the VM
 network_interface {
   label = "1-SRV"
   #label = "AUS-TEST-DataCenter/network/1-SRV"
   ipv4_gateway = "172.16.0.1"
   ipv4_address = "172.16.0.8"
   ipv4_prefix_length = "24"
 }
# Define Domain and DNS
 domain = "borrowersfirst.net"
 dns_servers = ["172.16.0.20", "172.16.0.21"]*/
custom_configuration_parameters {
#    terraform_customer_name     = "customer_name"
#    terraform_datacenter        = "dc_name"
#    terraform_product           = "product_name"
#    terraform_role              = "app"
#    terraform_node              = "1"
#      terraform_created = "Yes"
      guestinfo.coreos.config.data.encoding = "base64"
      guestinfo.coreos.config.data          = "${base64encode(data.ignition_config.node.*.rendered[count.index])}"
      # WARNING: The below keys names should be equal to those used in the Jinja filter in vmware_inventory.ini
      tf_environment        = "${ var.environment }"
      tf_provider           = "${ var.provider }"
      tf_role               = "${ var.server_role }"
      tf_node_num           = "${ count.index+1 }"
      tf_terraform_created  = "yes"
      tf_os                 = "CoreOS"
  }
# Be sure to check out the 'wait for instance' feature mentioned here:
#   https://github.com/hashicorp/terraform/issues/2811
# Define Time Zone
# time_zone = "America/New_York"
}
output "ip_address" {
  value = ["${vsphere_virtual_machine.node.*.network_interface.0.ipv4_address}"]
}
```