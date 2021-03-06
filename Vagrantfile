# -*- mode: ruby -*-
# vi: set ft=ruby :

$quick_setup = <<SCRIPT

# Check that the repository is mounted into the VM:
if [ ! -f /vagrant/build.sh ]; then
  echo "Could not find '/vagrant/build.sh'. Is the directory mounting into Vagrant?" && exit 1
fi

# Install OVFTool
echo "Checking for ovftool and if it's not installed, installing it."
[ -f /usr/bin/ovftool ] || sudo /vagrant/tools/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle --eulas-agreed --required
_OVFTOOL_VERSION=$(ovftool --version) && echo ${_OVFTOOL_VERSION}

# Install Ansible
echo "Checking for ansible and if it's not installed, installing it."
[ -f /usr/bin/ansible ] || sudo yum install epel-release ansible-2.3.1.0 -y
_ANSIBLE_VERSION=$(ansible --version) && echo ${_ANSIBLE_VERSION}

# Install pip
echo "Checking for pip and if it's not installed, installing it."
[ -f /usr/bin/pip ] || sudo yum install python-pip -y
_PIP_VERSION=$(pip --version) && echo ${_PIP_VERSION}

# Install pyvmomi
echo "Checking for pyvmomi and if it's not installed, installing it."
if ! pip --disable-pip-version-check list | grep pyvmomi ; then
  sudo pip --disable-pip-version-check install pyvmomi
fi
_PYVMOMI_VERSION=$(pip --disable-pip-version-check list | grep pyvmomi) && echo ${_PYVMOMI_VERSION}

SCRIPT

# All Vagrant configuration is done below. The "2" in Vagrant.configure
# configures the configuration version (we support older styles for
# backwards compatibility). Please don't change it unless you know what
# you're doing.
Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://vagrantcloud.com/search.
  config.vm.box = "boxcutter/centos7"

  # Disable automatic box update checking. If you disable this, then
  # boxes will only be checked for updates when the user runs
  # `vagrant box outdated`. This is not recommended.
  # config.vm.box_check_update = false

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  # NOTE: This will enable public access to the opened port
  # config.vm.network "forwarded_port", guest: 80, host: 8080

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine and only allow access
  # via 127.0.0.1 to disable public access
  # config.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: "127.0.0.1"

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  # config.vm.network "private_network", ip: "192.168.33.10"

  # Create a public network, which generally matched to bridged network.
  # Bridged networks make the machine appear as another physical device on
  # your network.
  # config.vm.network "public_network"

  # Share an additional folder to the guest VM. The first argument is
  # the path on the host to the actual folder. The second argument is
  # the path on the guest to mount the folder. And the optional third
  # argument is a set of non-required options.
  # config.vm.synced_folder "../data", "/vagrant_data"

  # Provider-specific configuration so you can fine-tune various
  # backing providers for Vagrant. These expose provider-specific options.
  # Example for VirtualBox:
  #
  # config.vm.provider "virtualbox" do |vb|
  #   # Display the VirtualBox GUI when booting the machine
  #   vb.gui = true
  #
  #   # Customize the amount of memory on the VM:
  #   vb.memory = "1024"
  # end
  #
  # View the documentation for the provider you are using for more
  # information on available options.

  # Enable provisioning with a shell script. Additional provisioners such as
  # Puppet, Chef, Ansible, Salt, and Docker are also available. Please see the
  # documentation for more information about their specific syntax and use.
  # config.vm.provision "shell", inline: <<-SHELL
  #   apt-get update
  #   apt-get install -y apache2
  # SHELL
  config.vm.provision "shell" do |s|
    s.inline = $quick_setup
  end
end
