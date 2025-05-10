#!/bin/sh

# Please refer to the code for implementation details.
# sh ./build_ueransimers.sh 3 --build // This will create 3 gNBs and 6 UEs and start the docker-compose with the new services, --build flag is optional

NUM="$1"
if [ -z "$NUM" ]; then
  echo "Usage: $0 <number_of_instances>"
  exit 1
fi
UE_COUNT=$(expr "$NUM" \* 2)

GNBS_DIR="config/extra-gnbs"
UES_DIR="config/extra-ues"
DOCKER_FILE="docker-compose-additions.yaml"
DOCKER_BASE_FILE="docker-compose-template.yaml"

LOGIN_URL="http://localhost:5000/api/login"
SUBSCRIBER_URL="http://localhost:5000/api/subscriber"
MNC=93

ADMIN_USER=admin
ADMIN_PASS=free5gc

get_access_token() {
  echo "Logging in to get the access token..."
  response=$(curl -s -X POST "$LOGIN_URL" \
    -H "Content-Type: application/json" \
    -d "{\"username\": \"${ADMIN_USER}\", \"password\": \"${ADMIN_PASS}\"}")

  access_token=$(echo "$response" | jq -r '.access_token')
  echo "Access token retrieved successfully."
}
get_access_token

delete_subscriber() {
  IMSI=$1
  TMNC=$2
  curl -s -X DELETE "$SUBSCRIBER_URL/$IMSI/208${TMNC}" \
    -H "Token: $access_token"
}

if [ "$(ls -A "$UES_DIR"/*.yaml 2>/dev/null)" ]; then
  i=2
  for ue_file in "$UES_DIR"/*.yaml; do
    full_imsi="imsi-208${MNC}000000000${i}"
    delete_subscriber "$full_imsi" "$MNC"
    i=$((i + 1))
  done
  rm -f "$UES_DIR"/*.yaml
fi


if [ "$(ls -A "$GNBS_DIR"/*.yaml 2>/dev/null)" ]; then
  rm -f "$GNBS_DIR"/*.yaml
fi

rm -f "$DOCKER_FILE"

mkdir -p "$GNBS_DIR"
mkdir -p "$UES_DIR"

cp "$DOCKER_BASE_FILE" "$DOCKER_FILE"

I=1
while [ "$I" -le "$NUM" ]; do
  IMSI1=$(printf "%03d" $(( (I - 1) * 2 + 2 )))
  IMSI2=$(printf "%03d" $(( (I - 1) * 2 + 3 )))

  GNB_FILE="$GNBS_DIR/gnbcfg${I}.yaml"
  UE_FILE1="$UES_DIR/uecfg${I}_1.yaml"
  UE_FILE2="$UES_DIR/uecfg${I}_2.yaml"

  cat > "$GNB_FILE" <<EOL
mcc: "208"
mnc: "$MNC"
nci: "0x000000010"
idLength: 32
tac: 1
linkIp: 127.0.0.1
ngapIp: gnb${I}.free5gc.org
gtpIp: gnb${I}.free5gc.org
amfConfigs:
  - address: amf.free5gc.org
    port: 38412
slices:
  - sst: 0x1
    sd: 0x010203
  - sst: 0x1
    sd: 0x112233
ignoreStreamIds: true
EOL

  # Helper function to write UE YAML and register
  write_and_register_ue() {
    local UE_FILE=$1
    local IMSI=$2
    cat > "$UE_FILE" <<EOL
supi: "imsi-208${MNC}0000000${IMSI}"
mcc: "208"
mnc: "$MNC"
key: "8baf473f2f8fd09487cccbd7097c6862"
op: "8e27b6af0e692e750f32667a3b14605d"
opType: "OPC"
amf: "8000"
imei: "356938035643803"
imeiSv: "4370816125816151"
gnbSearchList:
  - 127.0.0.1
  - gnb${I}.free5gc.org
uacAic:
  mps: false
  mcs: false
uacAcc:
  normalClass: 0
  class11: false
  class12: false
  class13: false
  class14: false
  class15: false
sessions:
  - type: "IPv4"
    apn: "internet"
    slice:
      sst: 0x01
      sd: 0x010203
  - type: "IPv4"
    apn: "internet"
    slice:
      sst: 0x01
      sd: 0x112233
configured-nssai:
  - sst: 0x01
    sd: 0x010203
  - sst: 0x01
    sd: 0x112233
default-nssai:
  - sst: 1
    sd: 1
integrity:
  IA1: true
  IA2: true
  IA3: true
ciphering:
  EA1: true
  EA2: true
  EA3: true
integrityMaxRate:
  uplink: "full"
  downlink: "full"
EOL

  # Register UE
  curl -s -X POST "$SUBSCRIBER_URL/imsi-208${MNC}0000000${IMSI}/208${MNC}" \
    -H "Content-Type: application/json" \
    -H "Token: $access_token" \
    -d @- <<EOF
{
  "userNumber": 1,
  "ueId": "imsi-208${MNC}0000000${IMSI}",
  "plmnID": "208${MNC}",
  "AuthenticationSubscription": {
    "authenticationMethod": "5G_AKA",
    "permanentKey": {
      "permanentKeyValue": "8baf473f2f8fd09487cccbd7097c6862",
      "encryptionKey": 0,
      "encryptionAlgorithm": 0
    },
    "sequenceNumber": "000000000023",
    "authenticationManagementField": "8000",
    "milenage": {
      "op": {
        "opValue": "",
        "encryptionKey": 0,
        "encryptionAlgorithm": 0
      }
    },
    "opc": {
      "opcValue": "8e27b6af0e692e750f32667a3b14605d",
      "encryptionKey": 0,
      "encryptionAlgorithm": 0
    }
  },
  "AccessAndMobilitySubscriptionData": {
    "gpsis": ["msisdn-"],
    "subscribedUeAmbr": {
      "uplink": "1 Gbps",
      "downlink": "2 Gbps"
    },
    "nssai": {
      "defaultSingleNssais": [],
      "singleNssais": [
        {
          "sst": 1,
          "sd": ""
        }
      ]
    }
  },
  "SessionManagementSubscriptionData": [
    {
      "singleNssai": {
        "sst": 1,
        "sd": ""
      },
      "dnnConfigurations": {}
    }
  ],
  "SmfSelectionSubscriptionData": {
    "subscribedSnssaiInfos": {
      "01": {
        "dnnInfos": []
      }
    }
  },
  "AmPolicyData": {
    "subscCats": ["free5gc"]
  },
  "SmPolicyData": {
    "smPolicySnssaiData": {
      "01": {
        "snssai": {
          "sst": 1,
          "sd": ""
        },
        "smPolicyDnnData": {}
      }
    }
  },
  "FlowRules": [],
  "QosFlows": [],
  "ChargingDatas": []
}
EOF
> /dev/null
  }

  write_and_register_ue "$UE_FILE1" "$IMSI1"
  write_and_register_ue "$UE_FILE2" "$IMSI2"

  # Docker service
  cat >> "$DOCKER_FILE" <<EOF

  ueransim${I}:
    container_name: ueransim${I}
    build:
      context: ./ueransim
    command: sh ./run.sh
    volumes:
      - ./config/extra-gnbs/gnbcfg${I}.yaml:/ueransim/config/gnbcfg.yaml
      - ./config/extra-ues/uecfg${I}_1.yaml:/ueransim/config/uecfg1.yaml
      - ./config/extra-ues/uecfg${I}_2.yaml:/ueransim/config/uecfg2.yaml
      - ./ueransim/packet_forwarder_duo.py.py:/ueransim/config/packet_forwarder.py
      - ./ueransim/run.sh:/ueransim/run.sh
    cap_add:
      - NET_ADMIN
    devices:
      - "/dev/net/tun"
    networks:
      privnet:
        aliases:
          - gnb.free5gc.org
    depends_on:
      - free5gc-amf
      - free5gc-upf
EOF

  I=$((I + 1))
done

cat >> "$DOCKER_FILE" <<EOF

networks:
  privnet:
    ipam:
      driver: default
      config:
        - subnet: 10.100.200.0/24
    driver_opts:
      com.docker.network.bridge.name: br-free5gc

volumes:
  dbdata:

EOF

echo "Generated $NUM gNB, $UE_COUNT UE config pairs and Docker services in $DOCKER_FILE"

if printf '%s\n' "$@" | grep -q -- '--build'; then
  echo "Bringing down existing Docker Compose services..."
  sudo docker-compose down

  echo "Starting Docker Compose with new services..."
  sudo docker-compose -f "$DOCKER_FILE" up --build

  echo "Successfully started the new Docker Compose services with gNB/UE instances."
fi