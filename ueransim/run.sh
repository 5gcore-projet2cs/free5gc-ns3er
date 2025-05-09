#!/bin/sh

# apt install python3-pip libpcap-dev -y
# pip install scapy

python3 ./config/packet_forwarder.py &
./nr-gnb -c ./config/gnbcfg.yaml