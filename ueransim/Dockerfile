FROM gcc:9.4.0 AS builder

LABEL maintainer="Free5GC <support@free5gc.org>"

ENV DEBIAN_FRONTEND=noninteractive

ARG TARGET_ARCH=x86_64

# Install dependencies
RUN apt-get update \
    && apt-get install libsctp-dev lksctp-tools iproute2 -y \
    && wget https://github.com/Kitware/CMake/releases/download/v3.22.1/cmake-3.22.1-linux-${TARGET_ARCH}.sh -O cmake_installer.sh \
    && chmod +x cmake_installer.sh \
    && ./cmake_installer.sh --skip-license \
    && git clone -b master -j `nproc` https://github.com/aligungr/UERANSIM \
    && cd ./UERANSIM \
    && make

FROM bitnami/minideb:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies + ping
RUN apt-get update \
    && apt-get install libsctp-dev lksctp-tools iproute2 iputils-ping procps psmisc pip traceroute net-tools -y \
    && apt-get clean

RUN pip install --no-cache-dir scapy

WORKDIR /ueransim

RUN mkdir -p config/ binder/

COPY --from=builder /UERANSIM/build/nr-gnb .
COPY --from=builder /UERANSIM/build/nr-ue .
COPY --from=builder /UERANSIM/build/nr-cli .
COPY --from=builder /UERANSIM/build/nr-binder binder/
COPY --from=builder /UERANSIM/build/libdevbnd.so binder/

VOLUME [ "/ueransim/config" ]
