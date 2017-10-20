#!/usr/bin/python

'''
TODO:
- Check for folder existence in vCenter.
- Test the script with more than one depth of sub-folders in VMware.
    Ex: Rather than just 'TF_folder', 'UAT/TF_folder'.
'''

'''
-----------------------------
Script is used to move a VM (created by Packer) from the 'Discovered virtual machine' folder, to the destination Template folder.

Requires the following environment variable to be set:
VMWARE_PASSWORD

Example running the script:

  export VMWARE_PASSWORD=the_secret_password_for_the_vcenter_user
  ./vm_mover.py \
    --host bf-aus-vcenter1.borrowersfirst.net \
    --port 443 \
    --vmware_user vmware_test_svc@borrowersfirst.net \
    --datacenter_name AUS-TEST-DataCenter \
    --template_folder TF_folder \
    --vm_name packer-coreos-template

-----------------------------
'''

from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import atexit
#import time
import argparse
import ssl
import os, sys


def GetArgs():
   parser = argparse.ArgumentParser(
       description='Script is used to move a VM (created by Packer) from the \'Discovered virtual machine\' folder, to the destination Template folder. Please also set the corresponding environment variable (_VCENTER_USER_PASSWORD).')
   parser.add_argument('-s', '--host', required=True, action='store',
                       help='Remote host to connect to')
   parser.add_argument('-o', '--port', type=int, default=443, action='store',
                       help='Port to connect on')
   parser.add_argument('-u', '--vmware_user', required=True, action='store',
                       help='User name to use when connecting to host')
   parser.add_argument('-d', '--datacenter_name', required=True, action='store',
                       help='Which datacenter is the VM located in? Example: AUS-TEST-DataCenter')
   parser.add_argument('-f', '--template_folder', required=True, action='store',
                       help='Specify the destination template folder for the vm. Example: TF_folder')
   parser.add_argument('-n', '--vm_name', required=True, action='store',
                       help='Specify the name of the VM to be moved into the template folder. (Should correspond to the VM name generated by Packer.) Example: packer-coreos-template')
   args = parser.parse_args()
   return args

def main():

    args = GetArgs()

    dc_name = args.datacenter_name
    tf_name = args.template_folder
    virtualmachine_name = args.vm_name

    if os.environ.get('_VCENTER_USER_PASSWORD'):
      vmware_password = os.environ['_VCENTER_USER_PASSWORD']
    else:
      print "ERROR: Please set the environment variable \'_VCENTER_USER_PASSWORD\' for the vCenter password."
      sys.exit(1)

    context = None
    if hasattr(ssl, '_create_unverified_context'):
      context = ssl._create_unverified_context()
    si = SmartConnect(host=args.host,
                     user=args.vmware_user,
                     pwd=vmware_password,
                     port=int(args.port),
                     sslContext=context)
    if not si:
       print("Could not connect to the specified host using specified "
             "vmware_user and vmware_password")
       return -1

    atexit.register(Disconnect, si)

    # Get vcenter content object
    content = si.RetrieveContent()

    # # Get list of DCs in vCenter and set datacenter to the vim.Datacenter object corresponding to the "AUS-TEST-DataCenter" DC
    datacenters = content.rootFolder.childEntity
    for dc in datacenters:
      if dc.name == dc_name:
        datacenter = dc

    # Get List of Folders in the "--data_center" DC and set:
    #    source_folder to the vim.Folder object corresponding to the "Discovered virtual machine" folder
    #    destination_folder to the vim.Folder object corresponding to the "TF_folder" folder
    dcfolders = datacenter.vmFolder

    vmfolders = dcfolders.childEntity
    for folder in vmfolders:
         if folder.name == "Discovered virtual machine":
             source_folder = folder
         if folder.name == tf_name:
             destination_folder = folder

    foundvm = False
    for _vm in source_folder.childEntity:
      if _vm.name == virtualmachine_name:
        vm=_vm
        foundvm = True

    if not foundvm:
      print "ERROR: Could not find VM {}. Please ensure that the Packer build was successful.".format(virtualmachine_name)
      sys.exit(1)

    destination_folder.MoveIntoFolder_Task([vm,])

    print "Script has run successfully, and the VM has been moved."


if __name__ == "__main__":
    main()
