#!/bin/bash
set -e
set +x

# ToDo:
#    - Test the script with more than one depth of sub-folders in VMware.
#     Ex: Rather than just 'TF_folder', 'UAT/TF_folder'. (Ansible handles the folders differently to the vm_mover.py script.)
#    - Potentially remove open-vm-tools after Terraform run, and manage it with Ansible for upgrade purposes? Or purhaps just make your own: https://hub.docker.com/r/godmodelabs/open-vm-tools/~/dockerfile/

# Requirements:
#  Connectivity to:
#  - The VM and build server require connectivity to stable.release.core-os.net
#  - The build server requires SSH and VNC (port 5944-5954) connectivity to the virtual machine it has just built.
#  - Connectivity to pull at least this Docker image: docker://godmodelabs/open-vm-tools for CoreOS.
#  During the build of the template, a VM is created, this VM requires DHCP.

# Packer v1.1.0
# Python 2.7.10
# ansible 2.3.1.0
# pyvmomi (6.5.0.2017.5.post1)

# ----------------------------------------------------------------------------------
# Formatting

BLUE="\033[0;34m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"
HR="\n--------------------------------------------------------------------------------------------------------------------------------"

# --------------------------------
# Usage:

usage () {

cat <<_EOF_

Script Usage:

Description:
  The $0 script is used to wrap operations that download the specified CoreOS image, transform the OVF to specifications, and push the
  files to a vSphere cluster/ESXi server as a VM. Afterwards, Ansible will convert the VM to a vSphere template.
  The script operates on the MASTER branch of the repository, from the root directory of the repository.

Usage:
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

Options:
  $0 { --help | --channel }

 Usage: $0 [OPTIONS]
  Options:
    -h, --help  Show usage only.
    -c, --channel [channel=stable]  REQUIRED - Use specific coreos channel: alpha, beta, stable.

 Requirements:
   The $0 script requires the following tools:

     1) CentOS based OS
     2) ovftool - VMware tool that can be installed from repo-root/tools.
       2.1) Downloadable from https://my.vmware.com/web/vmware/details?productId=614&downloadGroup=OVFTOOL420
            $ sudo repo-main/tools/VMware-ovftool-4.2.0-5965791-lin.x86_64.bundle --eulas-agreed --required
     3) bunzip2
     4) sed
     5) pip
       $ sudo yum install python-pip -y
     6) pyvmomi - Python SDK for the VMware vSphere API
       $ sudo pip install pyvmomi

_EOF_
exit 1
}

# --------------------------------
# Variables:

# Declare mover python script

VM_MOVER_SCRIPT_FILE="vm_mover.py"


# Initially set _CHANNEL arg to false

_CHANNEL=false


# ----------------------------------------------------------------------------------
# Script parameters and Sanity Checking - Inputs (Environment variables):

sanity_checks() {
  # Check that the base OS is a RedHat derivative

  if [[ ! -L /etc/redhat-release ]] ; then
    echo -e "${RED}${HR}\nBase OS is not CentOS.${NC}" && usage
  fi

  # Check that the required tools are installed

  _TOOLS=(
    'ovftool'
    'bunzip2'
    'sed'
    'pip'
    )

  for tool in "${_TOOLS[@]}" ; do
    if ! which "${_TOOLS}" >/dev/null ; then
      echo -e "${RED}\"${_TOOLS}\" - Tool is not found on path. Either install the tool ${_TOOLS} or add it to your path.${HR}${NC}"
      exit 1
    fi
  done

  # Check that pip pyvmomi is installed

  if ! pip --disable-pip-version-check freeze | grep --quiet pyvmomi ; then
    echo -e "${RED}${HR}\n\"pyvmomi\" - Tool is not found on path. Either install the tool pyvmomi with pip or add it to your path.${HR}${NC}"
    exit 1
  fi

  # Check that the mover script is available

  if [[ ! -f "${VM_MOVER_SCRIPT_FILE}" ]] ; then
    echo -e "${RED}${HR}\nERROR Could not find \"${VM_MOVER_SCRIPT_FILE}\".${HR}${NC}"
    exit 1
  fi

  # Check that environmental variables are not null

  required_vars=(
    _COREOS_ROOT_DISK_SIZE_GB
    _ESXI_DATASTORE
    _ESXI_NETWORK
    _ESXI_SERVER
    _VCENTER_CLUSTER
    _VCENTER_DATACENTER
    _VCENTER_SERVER
    _VCENTER_TEMPLATE_FOLDER
    _VCENTER_USER
    _VCENTER_USER_PASSWORD
    )

  missing_vars=()
  for i in "${required_vars[@]}" ;  do
    test -n "${!i:+y}" || missing_vars+=("$i")
  done

  if [ ${#missing_vars[@]} -ne 0 ] ; then
    echo -e "${RED}${HR}\nThe following variables are not set, but should be:${NC}" >&2
    printf ' %q\n' "${missing_vars[@]}" >&2
    usage
  fi
}

# ----------------------------------------------------------------------------------
# Functions:

main () {
  # Main script function to call all other functions

  echo -e "${GREEN}${HR}\nBeginning build script. ($0)${HR}${NC}"
  sanity_checks
  update_image
  update_ovf
  upload_new_image
  # gen_ignition
  # build
  # move_vm
  convert_build_vm_to_template
  script_clean_up
  echo -e "${GREEN}${HR}\nFinished build script. ($0)${HR}${NC}"
}

# Packer igintion
# gen_ignition() {
#   echo -e "${GREEN}${HR}\nGenerating CoreOS Ignition...${HR}${NC}"
#   ignition_gen/ignition_gen.sh
#   echo -e "${GREEN}${HR}\nGenerating CoreOS Ignition has completed.${HR}${NC}"
# }

# Packer build
# build() {
#   # Build the virtual machine:
#   echo "==> Building..."
#   packer build \
#     -var "vm_name=${VM_TEMPLATE_NAME}" \
#     -var "packer_build_template_file=${PACKER_BUILD_TEMPLATE_FILE}" \
#     -var "packer_esx_server=${PACKER_ESXI_SERVER}" \
#     -var "packer_vmware_remote_ssh_user_name=${PACKER_VMWARE_REMOTE_SSH_USER_NAME}" \
#     -var "packer_vmware_remote_ssh_user_password=${PACKER_VMWARE_REMOTE_SSH_USER_PASSWORD}" \
#     -var "packer_esxi_datastore=${PACKER_ESXI_DATASTORE}" \
#     -var-file ignition_gen/ignition-packer-var.json \
#     "${PACKER_BUILD_TEMPLATE_FILE}"
#   echo "==> Building has completed."
# }

# Packer move
# move_vm() {
#   # Move the virtual machine to the correct folder

#   echo -e "${GREEN}${HR}\nMoving VM...${HR}${NC}"
#   python vm_mover.py \
#     --host "${_VCENTER_SERVER}" \
#     --port "${_VCENTER_HOST_PORT}" \
#     --vmware_user "${_VCENTER_USER}" \
#     --datacenter_name "${_VCENTER_DATACENTER}" \
#     --template_folder "${_VCENTER_TEMPLATE_FOLDER}" \
#     --vm_name "${VM_TEMPLATE_NAME}"
#   echo -e "${GREEN}${HR}\nMoving the VM has completed.${HR}${NC}"
# }

update_image () {
  # Download the latest CoreOS files

  if [[ "${_CHANNEL}" = "stable" ]] ; then
    download_centos
  elif [[ "${_CHANNEL}" = "alpha" ]]; then
    download_centos
  elif [[ "${_CHANNEL}" = "beta" ]]; then
    download_centos
  else
    echo -e "${RED}${HR}\n\"${_CHANNEL}\" - This is not a valid CoreOS release channel.${HR}${NC}" && usage
  fi
}

download_centos () {
  # CoreOS URLs

  _CORE_OS_OVF_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ovf
  _CORE_OS_VMDK_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova_image.vmdk.bz2
  _CORE_OS_VERSION_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/version.txt

  # Download version.txt

  echo -e "${GREEN}${HR}\nDownloading CoreOS version information.${HR}${NC}"
  find . -maxdepth 1 -type f -name "version*.txt" -delete
  curl -fSLO "${_CORE_OS_VERSION_URL}"
  CORE_OS_VERSION=$(grep COREOS_VERSION= version.txt | sed -r 's/^.{15}//')
  mv version.txt version-${_CHANNEL}-${CORE_OS_VERSION}.txt

  # Download CoreOS OVF file

  echo -e "${GREEN}${HR}\nDownloading CoreOS OVF configuration file.${HR}${NC}"
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova*.ovf" -delete
  curl -fSL "${_CORE_OS_OVF_URL}" -o "coreos_production_vmware_ova-${_CHANNEL}-${CORE_OS_VERSION}.ovf"

  # Download zipped CoreOS VMDK file

  echo -e "${GREEN}${HR}\nDownloading CoreOS VMDK disk file.${HR}${NC}"
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.bz2" -delete
  curl -fSL "${_CORE_OS_VMDK_URL}" -o "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk.bz2"

  # Unzip VMDK file

  echo -e "${GREEN}${HR}\nExtracting CoreOS VMDK.${HR}${NC}"
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.vmdk" -delete
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk.bz2" -exec bunzip2 {} \;

  CORE_OS_VMDK_FILE=$(ls | grep "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk")
  CORE_OS_OVF_FILE=$(ls | grep "coreos_production_vmware_ova-${_CHANNEL}-${CORE_OS_VERSION}.ovf")

  VM_TEMPLATE_NAME=$(echo ${CORE_OS_OVF_FILE} | sed 's,\.ovf,,')
}

update_ovf () {

  # Update the ovf file supplied by CoreOS
  # 1 - Change the reference vmdk file name
  # 2 - Change the disk capacity to 10
  # 3 - Change the disk allocation units to GigaBytes
  # 4 - Change the machine name to "coreos-channel-versionNumber"
  # 5 - Change the VMware Linux type
  # 6 - Change the VMware VM version to latest


  if [[ ! -f ${CORE_OS_OVF_FILE} ]] ; then
    echo -e "${RED}${HR}\nCoreOS OVF configuration file - File does not exist.${NC}"
    exit 1
  elif [[ ! -f ${CORE_OS_VMDK_FILE} ]] ; then
    echo -e "${RED}${HR}\nCoreOS VMDK disk file - File does not exist.${NC}"
    exit 1
  else
    echo -e "${GREEN}${HR}\nUpdating ${CORE_OS_OVF_FILE} with correct configuration.${HR}${NC}"
    sed -re "s,File ovf:href=\"coreos_production_vmware_ova_image.vmdk\",File ovf:href=\"${CORE_OS_VMDK_FILE}\"," -e "s,(ovf:capacity=\")[0-9]+(\"),\1${_COREOS_ROOT_DISK_SIZE_GB}\2," -e "s,(ovf:capacityAllocationUnits=\")[a-z]+(\"),\1GigaBytes\2," -e "s,<VirtualSystem ovf:id=\"coreos_production_vmware_ova\">,<VirtualSystem ovf:id=\"coreos-${_CHANNEL}-${CORE_OS_VERSION}\">," -e "s,other26xLinux64Guest,coreos64Guest," -e "s,<vssd:VirtualSystemType>.*</vssd:VirtualSystemType>,<vssd:VirtualSystemType>vmx-13</vssd:VirtualSystemType>," -e "s,VM Network,${_ESXI_NETWORK},g" ${CORE_OS_OVF_FILE} > ${CORE_OS_OVF_FILE}.tmp && mv ${CORE_OS_OVF_FILE}.tmp ${CORE_OS_OVF_FILE}
  fi
}

upload_new_image () {
  # Push the OVF and VMDK to the ESXi server
  OVF_PUSH_TARGET=${_VCENTER_SERVER}/${_VCENTER_DATACENTER}/host/${_VCENTER_CLUSTER}/${_ESXI_SERVER}

  if [[ ! -f ${CORE_OS_OVF_FILE} ]] ; then
    echo -e "${RED}${HR}\n\"CoreOS OVF configuration file\" - File does not exist.${HR}${NC}"
    exit 1
  fi
  if [[ ! -f ${CORE_OS_VMDK_FILE} ]] ; then
    echo -e "${RED}${HR}\n\"CoreOS VMDK disk file\" - File does not exist.${HR}${NC}"
    exit 1
  else
    echo -e "${GREEN}${HR}\nUploading ${CORE_OS_OVF_FILE} to ESX/vSphere.${HR}${NC}"
    ovftool --skipManifestCheck --disableVerification --noSSLVerify --diskMode=thin --datastore=${_ESXI_DATASTORE} --vmFolder=${_VCENTER_TEMPLATE_FOLDER} --overwrite ${CORE_OS_OVF_FILE} vi://${_VCENTER_USER}:${_VCENTER_USER_PASSWORD}@${OVF_PUSH_TARGET}
  fi
}

convert_build_vm_to_template(){
  # Convert the virtual machine to a template:
  # (Ansible runs on the localhost.)

  echo -e "${GREEN}${HR}\nConverting VM to template...${HR}${NC}"
  VCENTER_TEMPLATE_FOLDER_FULL_PATH_FOR_ANSIBLE="/${_VCENTER_TEMPLATE_FOLDER}"
  ansible-playbook \
    -e vcenter_server="${_VCENTER_SERVER}" \
    -e vcenter_user="${_VCENTER_USER}" \
    -e _vcenter_user_password="${_VCENTER_USER_PASSWORD}" \
    -e vcenter_datacenter="${_VCENTER_DATACENTER}" \
    -e vcenter_cluster="${_VCENTER_CLUSTER}" \
    -e vcenter_template_folder_full_path_for_ansible="${VCENTER_TEMPLATE_FOLDER_FULL_PATH_FOR_ANSIBLE}" \
    -e vm_template_name="${VM_TEMPLATE_NAME}" \
    ansible/playbooks/ansible_convert_to_template.yml
  echo -e "${GREEN}${HR}\nConverting the VM to a template has completed.${HR}${NC}"
}

script_clean_up () {
  echo -e "${GREEN}${HR}\nCleaning up ...${HR}${NC}"
  rm -f ${CORE_OS_VMDK_FILE} ${CORE_OS_OVF_FILE} version-${_CHANNEL}-${CORE_OS_VERSION}.txt
  unset _COREOS_ROOT_DISK_SIZE_GB
  unset _ESXI_SERVER
  unset _ESXI_DATASTORE
  unset _ESXI_NETWORK
  unset _VCENTER_CLUSTER
  unset _VCENTER_DATACENTER
  unset _VCENTER_SERVER
  unset _VCENTER_TEMPLATE_FOLDER
  unset _VCENTER_USER
  unset _VCENTER_USER_PASSWORD
}

# ----------------------------------------------------------------------------------
# Execution order:

while [[ $# > 1 ]]; do
  key="$1"
  shift
  case $key in
    -c|--channel)
      _CHANNEL="$1"
      shift
    ;;
    -h|--help|-?)
      usage
      shift
    ;;
    *)
      usage
    ;;
  esac
done

if [[ ${_CHANNEL} != "false" ]] ; then
    main
else
  echo -e "${RED}${HR}\nNothing to do. Is --channel set?${HR}${NC}" && usage
fi
