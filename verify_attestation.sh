#!/bin/bash
set -e
# Verify attestation and create secret to be injected
function usage() {
    cat <<EOF
Usage:
  verify-attestation [-p secret] [-m launch_measurement] -t tiktek_file -o ovmf_file -s sevtool -a api_minor -b api_major -c build_id -d policy

  Verify attestation and create secret to be injected

  -p secret: secret to be injected (minimum of 8 bytes)
  -m launch_measurement: launch measurement from QMP (result of query-sev-launch-measure)
  -t tiktek_file: file where sev-tool stored the TIK/TEK combination, defaults to tmp_tk.bin
  -o ovmf_file: location of OVMF file to calculate hash from, default is OVMF.fd
  -s sevtool: location of sevtool, default is current directory
  -a api_minor: api-minor SEV info from QMP (result of query-sev), default 22
  -b api_major: api-major SEV info from QMP (result of query-sev), default 0
  -c build_id: build-id from SEV info from QMP (result of query-sev), default 13
  -d policy: policy from SEV info (result of query-sev), default 1
EOF
}

# default values
OVMF=OVMF.fd
TIKTEK="certs/tmp_tk.bin"
SEVTOOL=sevtool
API_MINOR=22
API_MAJOR=0
BUILD_ID=13
POLICY=1
while getopts "p:m:i:t:o:s:" OPT; do
    case "${OPT}" in
        p)
            SECRET="${OPTARG}"
            ;;
        m)
            LAUNCH_MEASUREMENT="${OPTARG}"
            ;;
        t)
            TIKTEK="${OPTARG}"
            ;;
        o)
            OVMF="${OPTARG}"
            ;;
        s)
            SEVTOOL="${OPTARG}"
            ;;
        a)
            API_MINOR="${OPTARG}"
            ;;
        b)
            API_MAJOR="${OPTARG}"
            ;;
        c)
            BUILD_ID="${OPTARG}"
            ;;
        d)
            POLICY="${OPTARG}"
            ;;
        *)
            usage
            exit 1
            ;;
    esac
done

if [[ "${SECRET}" == "" || "${LAUNCH_MEASUREMENT}" == "" ]]; then
    usage
    exit 1
fi

# Calculate digest of OVMF.fd
echo ${OVMF}
ovmf_hash=$(sha256sum "${OVMF}" | awk '{print $1}')
echo "OVMF hash: $ovmf_hash"

# Dervie TIK from tiktek file
TIK=$(xxd -p "${TIKTEK}"  | tr -d '\n'  | tail -c 32)
echo "TIK: $TIK"

# Convert sev-info to hex
API_MINOR=$(printf "%x" ${API_MINOR})
API_MAJOR=$(printf "%x" ${API_MAJOR})
BUILD_ID=$(printf "%x" ${BUILD_ID})
POLICY=$(printf "%x" ${POLICY})
echo "SEV info: api_minor: ${API_MINOR}, api_major: ${API_MAJOR}, build_id: ${BUILD_ID}, policy: ${POLICY}"

# Derive mnonce and expected measurement from the launch_measurement
echo "${LAUNCH_MEASUREMENT}" | base64 -d | split -b 32
expected_measurement=$(cat xaa)
mnonce=$(cat xab)

# Run calc_measurement from sevtool
sudo ./sevtool --ofolder ./certs --calc_measurement 04 ${API_MAJOR} ${API_MINOR} ${BUILD_ID} ${POLICY} $ovmf_hash $mnonce $TIK

# Create packaged secret and its header
echo "${SECRET}" > ./certs/secret.txt
sudo ./sevtool --ofolder ./certs --package_secret

echo "Secret created in certs folder"
