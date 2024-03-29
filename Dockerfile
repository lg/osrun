# hadolint global ignore=DL3029,DL3018

FROM alpine:3.18

RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
  qemu-system-x86_64 qemu-hw-display-virtio-vga qemu-img samba socat websocat 7zip jq coreutils nmap-ncat novnc tzdata \
  aria2 wimlib cabextract bash chntpw cdrkit \
  && mkdir -p /cache/not-forwarded
COPY osrun /osrun
COPY win11-init /win11-init
ENTRYPOINT ["/osrun"]
