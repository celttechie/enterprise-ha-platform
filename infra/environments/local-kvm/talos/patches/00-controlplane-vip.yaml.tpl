# Talos patch to assign a resilient Layer-2 Virtual IP (VIP) to Control Plane nodes
# This VIP automatically fails over via Gratuitous ARP / VRRP if a master node drops
machine:
  network:
    interfaces:
      - interface: eth0
        dhcp: true
        vip:
          ip: ${CONTROLPLANE_VIP}
