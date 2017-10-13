#!/bin/bash
set -e
set +x

# Jason Ware
# https://github.com/jknsware
#
# Script Summary:
#   This script is used to build CoreOS VMs on VMware ESXi hosts.
#   * Pulls latest build based on flagged options
#   * Builds the template by changing the OVF file
#   * Push CoreOS machines to the ESXi/vSphere hosts
#   * Requires OVFtool from VMware to push the templated VM
#
# Reused code/ideas from:
#   William Lam
#   www.virtuallyghetto.com
#
#   Gary Clayburg
#   https://github.com/gclayburg

# TO DO:
#   * Omit <NetworkSection> ?

# Script Sections:
#    - Formatting
#    - Variables
#    - Sanity Checking and Script parameters - Inputs (Environment variables)
#    - Functions
#    - Trap functions (always run, even if the script errors out)
#    - Execution order
#    - Cleanup and unsetting variables



# ----------------------------------------------------------------------------------
# Formatting

BLUE="\033[0;34m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m"
HR="\n--------------------------------------------------------------------------------------------------------------------------------"

# ----------------------------------------------------------------------------------
# Usage
usage ()
{

cat <<_EOF_

Script Usage:

Description:
  The $0 script is used to wrap operations that download the specified CoreOS image, transform the OVF to specifications, and push the files to a VMware cluster/ESXi.
  The script operates on the MASTER branch of the repository, from the root directory of the repository (coreos-ignition-corp).

Usage:
  Script must be run from a CentOS machine either with Vagrant, container, or bare-metal.

  Ensure that the environment variables are set:

    1) "_ESXI_USERNAME" --       Used to authenticate to the ESXi or vSphere server.
    2) "_ESXI_PASSWORD" --       Used to authenticate to the ESXi or vSphere server.
    3) "_VCENTER_SERVER_NAME" -- Used to specify the ESXi or vSphere server name and the path of where the VM should be pushed to. Eg: vsphere.name.net/DataCenter-NAME/host/Cluster-Name/esxi-server.name.net
    4) "_ESXI_DATASTORE" --      Used to specify the data store or disk the VM will be stored.
    5) "_ESXI_FOLDER" --         Used to specify the vCenter folder to store the VM.
    6) "_ESXI_NETWORK" --        Used to specify the vCenter network to attach the VM to.

    Example:
      export _ESXI_USERNAME="bob"
      export _ESXI_PASSWORD="bobspassword"
      export _VCENTER_SERVER_NAME="vsphere.name.net/DataCenter-NAME/host/Cluster-Name/esxi-server.name.net"
      export _ESXI_DATASTORE="storage_disk"
      export _ESXI_FOLDER="bobsfolder"
      export _ESXI_NETWORK="VM Network"
    And then run the script from the coreos-ignition-corp directory:
      $0 deploy_coreos_on_esxhi.sh
    Or in one line:
      export _ESXI_USERNAME="bob"; export _ESXI_PASSWORD="bobspassword"; export _VCENTER_SERVER_NAME="vsphere.name.net/DataCenter-NAME/host/Cluster-Name/esxi-server.name.net"; export _ESXI_DATASTORE="storage_disk"; export _ESXI_FOLDER="bobsfolder"; _ESXI_NETWORK="VM Network; ./$0 deploy_coreos_on_esxi.sh

Options:
  $0 { --help | --skip_download | -channel }

 Usage: $0 [OPTIONS]
  Options:
    -h, --help  Show usage only.
    -s, --skip_download  Do not attempt to download of latest CoreOS.
    -c, --channel [channel=stable]  REQUIRED - Use specific coreos channel: alpha, beta, stable.
_EOF_
exit 1
}

# ----------------------------------------------------------------------------------
# Variables:

_CHANNEL=false

# ----------------------------------------------------------------------------------
# Script parameters and Sanity Checking - Inputs (Environment variables):

# Check that the base OS is a RedHat derivative
[ ! -f /etc/redhat-release ] && echo -e "${RED}${HR}\nBase OS is not CentOS.${NC}" && usage

# Check for required tools:
_TOOLS=(
  'ovftool'
  'bunzip2'
  'sed'
  'openssl'
  )

for tool in "${_TOOLS[@]}"; do
  if ! which "${_TOOLS}" >/dev/null; then
    echo -e "${RED}\"${_TOOLS}\" - Tool is not found on path. Either install the tool ${_TOOLS} or add it to your path.${NC}" && exit 1
  fi
done

# Check that environmental variables are set
[ -z ${_ESXI_USERNAME+x} ] && echo -e "${RED}\"_ESXI_USERNAME\" - Environment variable is not set.${NC}" && usage
[ -z ${_ESXI_PASSWORD+x} ] && echo -e "${RED}\"_ESXI_PASSWORD\" - Environment variable is not set.${NC}" && usage
[ -z ${_VCENTER_SERVER_NAME+x} ] && echo -e "${RED}\"_VCENTER_SERVER_NAME\" - Environment variable is not set.${NC}" && usage
[ -z ${_ESXI_DATASTORE+x} ] && echo -e "${RED}\"_ESXI_DATASTORE\" - Environment variable is not set.${NC}" && usage
[ -z ${_ESXI_FOLDER+x} ] && echo -e "${RED}\"_ESXI_FOLDER\" - Environment variable is not set.${NC}" && usage
[ -z ${_ESXI_NETWORK+x} ] && echo -e "${RED}\"_ESXI_NETWORK\" - Environment variable is not set.${NC}" && usage

# ----------------------------------------------------------------------------------
# Functions:


update_image () {
  # Download the latest CoreOS files

  if [[ "${_CHANNEL}" = "stable" ]] ; then
    download_centos
  elif [[ "${_CHANNEL}" = "alpha" ]]; then
    download_centos
  elif [[ "${_CHANNEL}" = "beta" ]]; then
    download_centos
  else
    echo -e "${RED}\"${_CHANNEL}\" - This is not a valid CoreOS release channel.${NC}" && usage
  fi
}

download_centos () {
  # CoreOS URLs
  _CORE_OS_OVF_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ovf
  _CORE_OS_VMDK_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova_image.vmdk.bz2
  _CORE_OS_VERSION_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/version.txt

  echo -e "${GREEN}${HR}\nDownloading CoreOS version information.${HR}${NC}"
  find . -maxdepth 1 -type f -name "version*.txt" -delete
  curl -fSLO "${_CORE_OS_VERSION_URL}"
  CORE_OS_VERSION=$(grep COREOS_VERSION= version.txt | sed -r 's/^.{15}//')
  mv version.txt version-${_CHANNEL}-${CORE_OS_VERSION}.txt

  echo -e "${GREEN}${HR}\nDownloading CoreOS OVF configuration file.${HR}${NC}"
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova*.ovf" -delete
  curl -fSL "${_CORE_OS_OVF_URL}" -o "coreos_production_vmware_ova-${_CHANNEL}-${CORE_OS_VERSION}.ovf"

  echo -e "${GREEN}${HR}\nDownloading CoreOS VMDK disk             file.${HR}${NC}"
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.bz2" -delete
  curl -fSL "${_CORE_OS_VMDK_URL}" -o "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk.bz2"

  echo -e "${GREEN}${HR}\nExtracting CoreOS VMDK.${HR}${NC}"
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.vmdk" -delete
  find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk.bz2" -exec bunzip2 {} \;

  CORE_OS_VMDK_FILE=$(ls | grep "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk")
  CORE_OS_OVF_FILE=$(ls | grep "coreos_production_vmware_ova-${_CHANNEL}-${CORE_OS_VERSION}.ovf")
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
    sed -re "s,File ovf:href=\"coreos_production_vmware_ova_image.vmdk\",File ovf:href=\"${CORE_OS_VMDK_FILE}\"," -e "s,(ovf:capacity=\")[0-9]+(\"),\110\2," -e "s,(ovf:capacityAllocationUnits=\")[a-z]+(\"),\1GigaBytes\2," -e "s,<VirtualSystem ovf:id=\"coreos_production_vmware_ova\">,<VirtualSystem ovf:id=\"coreos-${_CHANNEL}-${CORE_OS_VERSION}\">," -e "s,other26xLinux64Guest,coreos64Guest," -e "s,<vssd:VirtualSystemType>.*</vssd:VirtualSystemType>,<vssd:VirtualSystemType>vmx-13</vssd:VirtualSystemType>," -e "s,VM Network,${_ESXI_NETWORK},g" ${CORE_OS_OVF_FILE} > ${CORE_OS_OVF_FILE}.tmp && mv ${CORE_OS_OVF_FILE}.tmp ${CORE_OS_OVF_FILE}
  fi
}

upload_new_image () {
  # Push the OVF and VMDK to the ESXi server

  if [[ ! -f ${CORE_OS_OVF_FILE} ]] ; then
    echo -e "${RED}${HR}\"CoreOS OVF configuration file\" - File does not exist.${NC}"
    exit 1
  fi
  if [[ ! -f ${CORE_OS_VMDK_FILE} ]] ; then
    echo -e "${RED}${HR}\"CoreOS VMDK disk file\" - File does not exist.${NC}"
    exit 1
  else
    echo -e "${GREEN}${HR}\nUploading ${CORE_OS_OVF_FILE} to ESX/vSphere.${HR}${NC}"
    ovftool --skipManifestCheck --disableVerification --noSSLVerify --diskMode=thin --datastore=${_ESXI_DATASTORE} --vmFolder=${_ESXI_FOLDER} --overwrite ${CORE_OS_OVF_FILE} vi://${_ESXI_USERNAME}:${_ESXI_PASSWORD}@${_VCENTER_SERVER_NAME}
  fi
}

script_clean_up () {
  echo -e "${GREEN}${HR}\nCleaning up ...${HR}${NC}"
  rm -f ${CORE_OS_VMDK_FILE} ${CORE_OS_OVF_FILE} version-${_CHANNEL}-${CORE_OS_VERSION}.txt
  unset _ESXI_USERNAME
  unset _ESXI_PASSWORD
  unset _VCENTER_SERVER_NAME
  unset _ESXI_DATASTORE
  unset _ESXI_FOLDER
  unset _ESXI_NETWORK
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
  echo -e "${GREEN}${HR}\nBuilding and distributing a new CoreOS version to vCenter/ESXi server.${HR}${NC}"
  update_image
  update_ovf
  upload_new_image
else
  echo -e "${RED}${HR}\nNothing to do.${NC}"
fi


# ----------------------------------------------------------------------------------
# Cleanup and unsetting variables:

script_clean_up