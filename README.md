# coreos-ignition-corp

# OVFTool

**Script Usage:**

**Description:**
  The $0 script is used to wrap operations that download the specified CoreOS image, transform the OVF to specifications, and push the files to a VMware cluster/ESXi.
  The script operates on the MASTER branch of the repository, from the root directory of the repository (coreos-ignition-corp).

**Usage:**
  Script must be run from a CentOS machine either with Vagrant, container, or bare-metal.

  Ensure that the environment variables are set:

   1) "_ESXI_USERNAME" --       Used to authenticate to the ESXi or vSphere server.
   2) "_ESXI_PASSWORD" --       Used to authenticate to the ESXi or vSphere server.
   3) "_VCENTER_SERVER_NAME" -- Used to specify the ESXi or vSphere server name and the path of where the VM should be pushed to. Eg: vsphere.name.net/DataCenter-NAME/host/Cluster-Name/esxi-server.name.net
   4) "_ESXI_DATASTORE" --      Used to specify the data store or disk the VM will be stored.
   5) "_ESXI_FOLDER" --         Used to specify the vCenter folder to store the VM. Can also equal "false" to not include a folder.
   6) "_ESXI_NETWORK" --        Used to specify the vCenter network to attach the VM to.

```
   Example:
     export _ESXI_USERNAME="bob"
     export _ESXI_PASSWORD="bobspassword"
     export _VCENTER_SERVER_NAME="vsphere.name.net/DataCenter-NAME/host/Cluster-Name/esxi-server.name.net"
     export _ESXI_DATASTORE="storage_disk"
     export _ESXI_FOLDER="bobsfolder"
       or
         export _ESXI_FOLDER="false"
     export _ESXI_NETWORK="VM Network"
   And then run the script from the coreos-ignition-corp directory:
     $0 deploy_coreos_on_esxhi.sh
   Or in one line:
     export _ESXI_USERNAME="bob"; export _ESXI_PASSWORD="bobspassword"; export _VCENTER_SERVER_NAME="vsphere.name.net/DataCenter-NAME/host/Cluster-Name/esxi-server.name.net"; export _ESXI_DATASTORE="storage_disk"; export _ESXI_FOLDER="bobsfolder"; _ESXI_NETWORK="VM Network; ./$0 deploy_coreos_on_esxi.sh
```

**Options:**
  `$0 { --help | --channel }`

 Usage: `$0 [OPTIONS]`
  Options:
   -h, --help  Show usage only.
   -c, --channel [--channel stable]  REQUIRED - Use specific coreos channel: alpha, beta, stable.

```$ ./deploy_coreos_on_esxi.sh --channel stable```

## References

[CoreOS Container Linux on ESXi with OVFTool](http://anton.lindstrom.io/coreos-on-esxi/)
[Ignition Example Configs](https://coreos.com/ignition/docs/latest/examples.html)
[OVF Tool Usage for Import and Export Virtual Machine](http://www.itadminstrator.com/2014/06/ovf-tool-usage-for-import-and-export.html)
[OVF Reference](http://wiki.abiquo.com/display/ABI38/OVF+Reference#OVFReference-DiskSection)