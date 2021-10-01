#!/bin/bash
set -e
echo "***** Platform Owner *****"
# Generate your OCA
echo "Generate your OCA"
openssl ecparam -genkey -name secp384r1 -noout -out ec384-key-pair.pem
openssl ec -in ec384-key-pair.pem -pubout -out ec384pub.pem

if [ ! -d certs ]; then
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
echo "Get the images in the folder"
echo "Copy ubuntu iso image"
sudo cp /home/khushboo/amdsev/AMDSEV/distros/ubuntu-18.04.4-desktop-amd64.iso .
echo "Copy ubuntu qcow image"
sudo cp /home/khushboo/amdsev/AMDSEV/distros/ubuntu-18.04.qcow2 .
echo "Copy OVMF.fd"
sudo cp /home/khushboo/amdsev/AMDSEV/distros/OVMF.fd .

echo "***** Platform owner *****"
echo "Launch the image"
sudo ~/amd_qemu/bin/qemu-system-x86_64 -name sevtest -enable-kvm -cpu EPYC -machine q35 -smp 4,maxcpus=64 -m 4096M,slots=5,maxmem=30G -drive if=pflash,format=raw,unit=0,file=OVMF.fd,readonly -drive file=ubuntu-18.04.4-desktop-amd64.iso,media=cdrom -boot d -netdev user,id=vmnic -device e1000,netdev=vmnic,romfile= -drive file=ubuntu-18.04.qcow2,if=none,id=disk0,format=qcow2 -device virtio-scsi-pci,id=scsi,disable-legacy=on,iommu_platform=true -device scsi-hd,drive=disk0 -object sev-guest,id=sev0,cbitpos=47,reduced-phys-bits=1,policy=0x1,session-file=launch_blob.base64,dh-cert-file=godh.base64 -machine memory-encryption=sev0 -nographic -monitor telnet:127.0.0.1:5551,server,nowait -S -qmp tcp:127.0.0.1:5550,server,nowait
