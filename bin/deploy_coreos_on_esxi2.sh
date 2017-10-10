#!/bin/bash
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
#   * Function to build new OVA file with options
#   ** Omit <NetworkSection> ?
#   ** DONE - Update <References> <File> with new vmdk name
#   ** DONE - Update <VirtualSystem> with new template name
#   ** DONE - Update Linux type
#   ** DONE - Update VirtualSystemType
#   * Function to push to desired host (or vSphere)
#   * Handle secrets
#   * Update cmdline args
#   * Either create the template or pass along the job to build template

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
 Usage: $0 [OPTIONS] file
  Options:
    -h, --help  Show usage only.
    -d, --debug  Show user_data that will be created, but do not change anything or create any image.
    -s, --skip_download  Do not attempt to download of latest CoreOS.
    -c, --channel [channel=stable]  Use specific coreos channel: alpha, beta, stable.
    -u, --update_image  Only create and deploy user_data iso image.  VM must already exist.
    --core_os_hostname=worker1  Set hostname of new vm image to worker1.
_EOF_
exit 1
}

# ----------------------------------------------------------------------------------
# Script parameters and Sanity Checking - Inputs (Environment variables):

# Check for required tools:
_TOOLS=(
  'ovftool'
  'bunzip2'
  )

for tool in "${_TOOLS[@]}"; do
  if ! which "${_TOOLS}" >/dev/null; then
    echo -e "${RED}\"${_TOOLS}\" - Tool is not found on path. Either install the tool ${_TOOLS} or add it to your path.${NC}" && exit 1
  fi
done

# ----------------------------------------------------------------------------------
# Variables:

_CHANNEL=alpha
_DEBUG_ONLY=false
_SKIP_DOWNLOAD=false
_UPLOAD_NEW_IMAGE=true
_ESXI_USERNAME=
_ESXI_PASSWORD=
_VCENTER_SERVER_NAME

# CoreOS URLs
_CORE_OS_OVF_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ovf
_CORE_OS_VMDK_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova_image.vmdk.bz2
_CORE_OS_VERSION_URL=https://${_CHANNEL}.release.core-os.net/amd64-usr/current/version.txt

# Test CoreOS URLS
# https://alpha..release.core-os.net/amd64-usr/current/coreos_production_vmware_ova.ovf
# https://alpha.release.core-os.net/amd64-usr/current/coreos_production_vmware_ova_image.vmdk.bz2
# https://alpha.release.core-os.net/amd64-usr/current/version.txt

# ----------------------------------------------------------------------------------
# Functions:

# do_shell () {
# # Execute command in shell, while logging complete command to stdout
# # JW - Not sure what he was doing here.
#     echo "$(date +%Y-%m-%d_%T) --> $*"
#     eval "$*"
#     STATUS=$?
#     return $STATUS
# }


update_image () {
  if [[ -f $1 ]]; then
    # Assume user provided a file with custom settings and user_data file
    . $1
  else
    # Use default user_data with etcd running on all nodes and static IP
    echo "File not found: $1"
    usage
  fi

# JW - Not sure that this is needed
  # echo "hostname:   $CORE_OS_HOSTNAME"
  # echo "VM name:    $VM_NAME"
  # echo "VM network: $VM_NETWORK"
  # echo ""
  # echo "user_data:"

  if [ "${_SKIP_DOWNLOAD}" = false ]; then
    echo "${GREEN}${HR}Downloading CoreOS version information.${HR}${NC}"
    find . -maxdepth 1 -type f -name "version*.txt" -delete
    curl -fsSLO "${_CORE_OS_VERSION_URL}"
    CORE_OS_VERSION=$(grep COREOS_VERSION= version.txt | sed -r 's/^.{15}//')
    mv version.txt version-${_CHANNEL}-${CORE_OS_VERSION}.txt

    echo "${GREEN}${HR}Downloading CoreOS OVF configuration file.${HR}${NC}"
    find . -maxdepth 1 -type f -name "coreos_production_vmware_ova*.ovf" -delete
    curl -fsSL "${_CORE_OS_OVF_URL}" -o "coreos_production_vmware_ova-${_CHANNEL}-${CORE_OS_VERSION}.ovf"

    echo "${GREEN}${HR}Downloading CoreOS VMDK disk file.${HR}${NC}"
    find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.bz2" -delete
    curl -fsSL "${_CORE_OS_VMDK_URL}" -o "coreos_production_vmware_ova_image-${_CHANNEL}-${CORE_OS_VERSION}.vmdk.bz2"

    echo "${GREEN}${HR}Extracting CoreOS VMDK.${HR}${NC}"
    find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.vmdk" -delete
    find . -maxdepth 1 -type f -name "coreos_production_vmware_ova_image*.bz2" -exec bunzip2 {} \;
  fi

  CORE_OS_VMDK_FILE=$(ls | grep ".vmdk")
  CORE_OS_OVF_FILE=$(ls | grep ".ovf")

}

update_ovf () {
  # Update the ovf file supplied by CoreOS
  # 1 - Change the reference vmdk file name
  # 2 - Change the disk capacity to 10
  # 3 - Change the disk allocation units to GigaBytes
  # 4 - Change the machine name to "coreos-channel-versionNumber"
  # 5 - Change the VMware Linux type
  # 6 - Change the VMware VM version to latest

  sed -re "s,File ovf:href=\"coreos_production_vmware_ova_image.vmdk\",File ovf:href=\"${CORE_OS_VMDK_FILE}\"," -e "s,(ovf:capacity=\")[0-9]+(\"),\110\2," -e "s,(ovf:capacityAllocationUnits=\")[a-z]+(\"),\1GigaBytes\2," -e "s,<VirtualSystem ovf:id=\"coreos_production_vmware_ova\">,<VirtualSystem ovf:id=\"coreos-${_CHANNEL}-${CORE_OS_VERSION}\">," -e "s,other26xLinux64Guest,other3xLinux64Guest," -e "s,<vssd:VirtualSystemType>.*</vssd:VirtualSystemType>,<vssd:VirtualSystemType>vmx-13</vssd:VirtualSystemType>," ${CORE_OS_OVF_FILE} > ${CORE_OS_OVF_FILE}.tmp && mv ${CORE_OS_OVF_FILE}.tmp ${CORE_OS_OVF_FILE}.ovf

}

upload_new_image(){
 ovftool --disableVerification --noSSLVerify --diskMode=thin --datastore=datastore-ssd --overwrite ${CORE_OS_OVF_FILE} vi://${_ESXI_USERNAME}:${_ESXI_USERNAME}@{_VCENTER_SERVER_NAME}

#   # Using HTTP put API to upload both VMX/VMDK
#   echo "Uploading CoreOS VMDK file to ${ESXI_DATASTORE} ..."
#   curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CORE_OS_VMDK_FILE}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CORE_OS_VMDK_FILE}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

#   echo "Uploading CoreOS VMX file to ${ESXI_DATASTORE} ..."
#   curl -H "Content-Type: application/octet-stream" --insecure --user "${ESXI_USERNAME}:${ESXI_PASSWORD}" --data-binary "@${CORE_OS_OVF_FILE}" -X PUT "https://${ESXI_HOST}/folder/${VM_NAME}/${CORE_OS_OVF_FILE}?dcPath=ha-datacenter&dsName=${ESXI_DATASTORE}"

#   # Creates script to convert VMDK & register on ESXi host
#   echo "Creating script to convert and register CoreOS VM on ESXi ..."
#   cat > ${CORE_OS_ESXI_SETUP_SCRIPT} << __CORE_OS_ON_ESXi__


# # Change to CoreOS directory
# cd ${CORE_OS_DATASTORE_PATH}

# # Convert VMDK from 2gbsparse from hosted products to Thin
# vmkfstools -i ${CORE_OS_VMDK_FILE} -d thin coreos.vmdk

# # Remove the original 2gbsparse VMDKs
# rm ${CORE_OS_VMDK_FILE}

# # Update CoreOS VMX to reference new VMDK
# sed -i 's/${CORE_OS_VMDK_FILE}/coreos.vmdk/g' ${CORE_OS_OVF_FILE}

# # Update CoreOS VMX w/new VM Name
# sed -i "s/displayName.*/displayName = \"${VM_NAME}\"/g" ${CORE_OS_OVF_FILE}

# # Update CoreOS VMX to map to VM Network
# echo "ethernet0.networkName = \"${VM_NETWORK}\"" >> ${CORE_OS_OVF_FILE}

# # Update CoreOS VMX to include CD-ROM & mount cloud-config ISO
# cat >> ${CORE_OS_OVF_FILE} << __CLOUD_CONFIG_ISO__
# ide0:0.deviceType = "cdrom-image"
# ide0:0.fileName = "${CLOUD_CONFIG_ISO}"
# ide0:0.present = "TRUE"
# __CLOUD_CONFIG_ISO__

# # Register CoreOS VM which returns VM ID
# VM_ID=\$(vim-cmd solo/register ${CORE_OS_DATASTORE_PATH}/${CORE_OS_OVF_FILE})

# # Upgrade CoreOS Virtual Hardware from 4 to 9
# echo "Upgrade CoreOS Virtual Hardware from 4 to 9"

# vim-cmd vmsvc/upgrade \${VM_ID} vmx-09

# # PowerOn CoreOS VM
# echo "PowerOn CoreOS VM"
# vim-cmd vmsvc/power.on \${VM_ID}
# echo "VM ${VM_NAME} is now running using hostname: ${CORE_OS_HOSTNAME}"
#The first time coreos boots up, it will use DHCP to get a random IP address.  Later in the boot process, coreos will write the static.network file which overrides the DHCP behavior for the next boot.
#This workaround reboots this new server to allow it to use this static IP
#echo "Wating 60 seconds for power.on"
#sleep 60
#vim-cmd vmsvc/power.shutdown \${VM_ID}
#echo "Waiting for power.off"
#while vim-cmd vmsvc/power.getstate \${VM_ID} | grep on; do
#  echo -n "."
#  sleep 1
#done
#vim-cmd vmsvc/power.on \${VM_ID}



# __CORE_OS_ON_ESXi__
#   chmod +x ${CORE_OS_ESXI_SETUP_SCRIPT}

#   echo "Running ${CORE_OS_ESXI_SETUP_SCRIPT} script against ESXi host ..."
#   #todo use expect to supply password to ssh,
#   # and not prompt user for password if they have not setup ssh keys between the client and esxi server
#   ssh -o ConnectTimeout=300 ${ESXI_USERNAME}@${ESXI_HOST} < ${CORE_OS_ESXI_SETUP_SCRIPT}

#SCRIPT_OUT=$(expect -c "
#  spawn scp ${CORE_OS_ESXI_SETUP_SCRIPT} ${ESXI_USERNAME}@${ESXI_HOST}:
#  match_max 100000
#  expect {
#    \"*?assword:*\" {
#      send \"$ESXI_PASSWORD\r\"
#      expect eof
#    } eof {
#    }
#  }

#  spawn ssh -o ConnectTimeout=300 root@paladin \"chmod 755 ${CORE_OS_ESXI_SETUP_SCRIPT}; ./${CORE_OS_ESXI_SETUP_SCRIPT} \"
#  match_max 100000
#  expect {
#    \"*?assword:*\" {
#      send \"$ESXI_PASSWORD\r\"
#      expect eof
#    } eof {
#    }
#  }

#")
# echo "output: $SCRIPT_OUT"
}
#echo "Cleaning up ..."
#rm -f ${CORE_OS_ESXI_SETUP_SCRIPT}
#rm -f ${CORE_OS_VMDK_FILE}
#rm -f ${CORE_OS_OVF_FILE}
#rm -f ${CLOUD_CONFIG_ISO}
#rm -rf ${TMP_CLOUD_CONFIG_DIR}

while [[ $# > 1 ]]; do
  key="$1"
  shift
  case $key in
    -s|--skip_download)
      _SKIP_DOWNLOAD=true
    ;;
    -u|--update_image)
      _SKIP_DOWNLOAD=true
      _UPLOAD_NEW_IMAGE=false
    ;;
    -c|--channel)
      _CHANNEL="$1"
      shift
    ;;
    -d|--debug)
      _DEBUG_ONLY=true
    ;;
    -h|--help|-?)
      usage
      shift
    ;;
    --*=*)  # i.e.,  --core_os_hostname=mink1
      UPCASE=${key^^} #upcase
      UPNAME=${UPCASE#--}  #remove --
      SHORTNAME=${UPNAME%%=*} #remove value
      SHORTVAL=${key#*=} #remove name
      echo "overriding value ${SHORTNAME}=${SHORTVAL}"
      eval "${SHORTNAME}=${SHORTVAL}"
    ;;
    *)
      usage
            # unknown option
    ;;
  esac
done

update_image $1
if [[ "${_UPLOAD_NEW_IMAGE}" = true ]]; then
  upload_new_image
fi

# ----------------------------------------------------------------------------------
# Execution order: