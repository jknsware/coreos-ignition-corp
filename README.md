# coreos-ignition-corp

# Build script to deploy CoreOS on VMware

**Script Usage:**

**Description:**
  The $0 script is used to wrap operations that download the specified CoreOS image, transform the OVF to specifications, and push the
  files to a vSphere cluster/ESXi server as a VM. Afterwards, Ansible will convert the VM to a vSphere template.
  The script operates on the MASTER branch of the repository, from the root directory of the repository.

**Usage:**
  Script must be run from a CentOS machine either with Vagrant, container, or bare-metal.

  Ensure that the environment variables are set:

   01) "_COREOS_ROOT_DISK_SIZE_GB" -- Used to set the root disk size in GB. Default should be 10.
   02) "_ESXI_DATASTORE" --           Used to specify the data store or disk the VM will be stored.
   03) "_ESXI_NETWORK" --             Used to specify the vCenter network to attach the VM to.
   04) "_ESXI_SERVER" --              Used to specify the ESXi server.
   05) "_VCENTER_CLUSTER" --          Used to specify the vSphere cluster.
   06) "_VCENTER_DATACENTER" --       Used to specify the vSphere datacenter.
   07) "_VCENTER_SERVER" --           Used to specify the ESXi or vSphere server name and the path of where the VM should be pushed to.
   08) "_VCENTER_TEMPLATE_FOLDER" --  Used to specify the vCenter folder to store the VM.
   09) "_VCENTER_USER" --             Used to authenticate to the ESXi or vSphere server.
   10) "_VCENTER_USER_PASSWORD" --    Used to authenticate to the ESXi or vSphere server.

```
    Example:
      export _COREOS_ROOT_DISK_SIZE_GB="10"
      export _ESXI_DATASTORE="storage_disk"
      export _ESXI_NETWORK="VM Network"
      export _ESXI_SERVER="esxi01.name.net"
      export _VCENTER_CLUSTER="Cluster-Test"
      export _VCENTER_DATACENTER="DataCenter-Test"
      export _VCENTER_SERVER="vsphere.name.net"
      export _VCENTER_TEMPLATE_FOLDER="bobsfolder"
      export _VCENTER_USER="bob"
      export _VCENTER_USER_PASSWORD="bobspassword"

    And then run the script from the kraken-build directory:
      $0 deploy_coreos_on_esxhi.sh
    Or in one line:
      export _ESXI_SERVER="esxi01.name.net"; export _ESXI_DATASTORE="storage_disk"; export _ESXI_NETWORK="VM Network"; export _ESXI_DATASTORE="storage_disk"; export _VCENTER_CLUSTER="Cluster-Test"; export _VCENTER_DATACENTER="DataCenter-Test"; export _VCENTER_SERVER="vsphere.name.net"; export _VCENTER_TEMPLATE_FOLDER="bobsfolder"; export _VCENTER_USER="bob"; export _VCENTER_USER_PASSWORD="bobspassword"; ./$0 deploy_coreos_on_esxi.sh
```

**Options:**
  `$0 { --help | --channel }`

 Usage: `$0 [OPTIONS]`
  Options:
    -h, --help  Show usage only.
    -c, --channel [channel=stable]  REQUIRED - Use specific coreos channel: alpha, beta, stable.

 Requirements:
   The $0 script requires the following tools:

   1) CentOS based OS
   2) ovftool - VMware tool that can be installed from repo-root/tools.
     2.1) Downloadable from https://my.vmware.com/web/vmware/details?productId=614&downloadGroup=OVFTOOL420
          `$ sudo repo-main/tools/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle --eulas-agreed --required`
   3) bunzip2
   4) sed
   5) pip
     `$ sudo yum install python-pip -y`
   6) pyvmomi - Python SDK for the VMware vSphere API
     `$ sudo pip install pyvmomi`

   `$ ./build.sh --channel alpha`

## References

[CoreOS Container Linux on ESXi with OVFTool](http://anton.lindstrom.io/coreos-on-esxi/)

[Ignition Example Configs](https://coreos.com/ignition/docs/latest/examples.html)

[OVF Tool Usage for Import and Export Virtual Machine](http://www.itadminstrator.com/2014/06/ovf-tool-usage-for-import-and-export.html)

[OVF Reference](http://wiki.abiquo.com/display/ABI38/OVF+Reference#OVFReference-DiskSection)