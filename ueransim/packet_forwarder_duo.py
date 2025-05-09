from scapy.all import sniff, IP
import os

def packet_callback(packet):
    if IP in packet:
        if packet[IP].proto == 222:
            print('Received packet with proto 222')
            os.system("./nr-ue -c ./config/uecfg1.yaml")
            os.system("./nr-ue -c ./config/uecfg2.yaml")
        elif packet[IP].proto == 221:
            print('Received packet with proto 221')
            os.system(f"ping -I uesimtun1 -c 1 {bytes(packet[IP].payload).decode(errors='ignore')}")

sniff(filter="ip", prn=packet_callback, store=0)
