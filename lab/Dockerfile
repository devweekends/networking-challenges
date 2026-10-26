FROM ubuntu:24.04@sha256:68ee22004a9109b44973313b02ff7b1de250f1de0f5ecb628d73f579aaff33ac

# Build with: docker build -t networking-lab lab/
# Run with:   bash lab/start.sh   (or lab\start.ps1 in PowerShell)

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        iproute2 nftables tcpdump dnsmasq-base bind9-dnsutils traceroute \
        iputils-ping netcat-openbsd curl conntrack busybox nano isc-dhcp-client \
    && rm -rf /var/lib/apt/lists/*

# A marker file: toolkit/check-setup.sh looks for it to know it runs inside the lab.
# A short prompt: if you see "(lab)", you are inside the lab.
RUN printf '%s\n' 'networking lab image, ubuntu 24.04 with the course tools' > /etc/networking-lab-image \
    && printf '%s\n' "PS1='(lab) \\w # '" >> /root/.bashrc

WORKDIR /work

CMD ["bash"]
