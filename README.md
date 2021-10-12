# SEVAttestation

This project contains all the tools and scripts required to perform SEV attestation and injection of a secret.

## Dependencies
1. QEMU version 6.1 https://www.qemu.org/download/#source (released on August 24, 2021) - None of the previous versions support attestation and secret injection capabilites

## How to run
1. `git clone git@github.com:khushboo-dfn/SEVAttestation.git`
2. `cd SEVAttestation`
3. Prepare image
    - Get an Ubuntu server image
        `wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img` (Rename it to ubuntu-server.img)
    - Prepare iso
        `sudo cloud-localds ubuntu-server.iso user-data.yaml metadata.yaml`
4. Launch a QEMU image using `launch_qemu_image` script  
    `./launch_qemu_image.sh`
5. In another terminal, connect to the QEMU instance using QMP  
    `telnet 127.0.0.1 5550`
6. Run the following commands:  
    `{ "execute": "qmp_capabilities" }`  
    `{"return": {}}`

    `{ "execute": "query-sev" }`  
    `{"return": {"enabled": true, "api-minor": 22, "handle": 1, "state": "launch-secret", "api-major": 0, "build-id": 13, "policy": 1}}`  
      
    `{ "execute": "query-sev-launch-measure" }`  
    `{"return": {"data": "7vHlsVKpvBaUHU5jzpNtfLMFAljbBnVrkqO51p3Ny3sZHribEtvolLvSRs0SqW8a"}}`  
    Record these results to pass to the script in next step.  
7. In a third terminal, run the script to verify attestation  
    `./verify_attestation.sh -p secret_to_be_injected -m 7vHlsVKpvBaUHU5jzpNtfLMFAljbBnVrkqO51p3Ny3sZHribEtvolLvSRs0SqW8a`  
    This script assumes sev info parameters, location of qemu and OVMF.fd as default but they can be specified. Run `./verify_attestation.sh -h` to find arguments.
8. Inject secret via qmp  
    `{ "execute": "sev-inject-launch-secret",
       "arguments": { "packet-header": "AAAAAI0M2R8bw40sg0Hu8PsGRf2LGHcBJcECXCFgkTgnHU4VCLMWx8tz8iAEuW4IKQl/BA==", "secret": "usNTvLEGVvtB2rMHCw=="}}`  
    `{"return": {}}`  
9. Continue to launch the guest VM  
    `{ "execute": "cont"}`
