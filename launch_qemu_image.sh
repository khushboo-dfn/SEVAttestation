#!/bin/bash
set -e

function usage() {
    cat <<EOF
Usage:
  launch_qemu_image -i location_of_raw_image
  Launch a QEMU image 
  -i location_of_raw_image: default ubuntu-server.img
EOF
}

# default values
IMAGE="ubuntu-server.img"
while getopts "i:" OPT; do
    case "${OPT}" in
        i)
            IMAGE="${OPTARG}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [ ! -d certs ]; then
	echo "***** Platform Owner *****"
	# Generate your OCA
	echo "Generate your OCA"
	openssl ecparam -genkey -name secp384r1 -noout -out ec384-key-pair.pem
	openssl ec -in ec384-key-pair.pem -pubout -out ec384pub.pem

	# Make folder for certs
	echo "Make certs folder"
	mkdir -p certs

	# Run get_id command
	echo "Run get_id command"
	sudo ./sevtool --ofolder ./certs --get_id --verbose

	# Get the CEK_ASK from the AMD KDS server by running the generate_cek_ask command
	echo "Get the CEK_ASK from the AMD KDS server by running the generate_cek_ask command"
	sudo ./sevtool --ofolder ./certs --generate_cek_ask

	echo "Set ownership to self-owned"
	sudo ./sevtool --ofolder ./certs --set_self_owned

	echo "Run the pek_csr command to generate a certificate signing request for your PEK. This will allow you to take ownership of the platform."
	sudo ./sevtool --ofolder ./certs --pek_csr

	echo "Run the sign_pek_csr command to sign the CSR with the provided OCA private key"
	sudo ./sevtool --sign_pek_csr ./certs/pek_csr.cert ec384-key-pair.pem

	echo "Run the pek_cert_import command"
	sudo ./sevtool --pek_cert_import pek_csr.signed.cert oca.cert

	echo "Run the pdh_cert_export command"
	sudo ./sevtool --ofolder ./certs --pdh_cert_export

	echo "Run the get_ask_ark command"
	sudo ./sevtool --ofolder ./certs --get_ask_ark
	
	echo "Run the export_cert_chain command to export the PDH down to the ARK (AMD root) and zip it up"
	sudo ./sevtool --ofolder ./certs --export_cert_chain

	echo "****** Guest owner *****"
	echo "Generate launch blob"
	sudo ./sevtool --ofolder ./certs --generate_launch_blob 1
	base64 ./certs/launch_blob.bin > launch_blob.base64
	base64 ./certs/godh.cert > godh.base64
fi

echo "***** Platform owner *****"
echo "Launch the image"
sudo qemu-system-x86_64 \
	-name sevtest -enable-kvm \
	-cpu EPYC -machine q35 -smp 4,maxcpus=64 \
	-m 4096M,slots=5,maxmem=30G \
	-drive if=pflash,format=raw,readonly=on,file=OVMF.fd \ # Be sure to use the patched build of OVMF
	-drive file=${IMAGE},format=raw \
	-nographic -vnc :1 \
	-object sev-guest,id=sev0,cbitpos=47,reduced-phys-bits=1,policy=0x1,session-file=launch_blob.base64,dh-cert-file=godh.base64 \
	-machine memory-encryption=sev0 -S -qmp tcp:127.0.0.1:5550,server,nowait
