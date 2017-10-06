# coreos-ignition-corp

# OVFTool

ovftool --disableVerification --noSSLVerify --network="1-SRV" --diskMode=thin --datastore=vmh1-local --vmFolder=TF_folder --overwrite coreos-1465.8.0-stable-10GB-tmpl.ovf vi://username@borrowersfirst.net:password@bf-aus-vcenter1.borrowersfirst.net/AUS-TEST-DataCenter/host/AUS-TEST-CLSTR/aus-test-vmh1.borrowersfirst.net

## References

http://anton.lindstrom.io/coreos-on-esxi/
https://coreos.com/ignition/docs/latest/examples.html
http://www.itadminstrator.com/2014/06/ovf-tool-usage-for-import-and-export.html
http://wiki.abiquo.com/display/ABI38/OVF+Reference#OVFReference-DiskSection