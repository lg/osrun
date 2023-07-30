# build with: docker build -t arkalis-win-builder .
# run with: docker run -it --rm --device=/dev/kvm -v $(pwd)/cache:/cache arkalis-win-builder
#
# hadolint global ignore=DL3029,DL3018

FROM --platform=linux/amd64 alpine:3.18

RUN apk add --no-cache qemu-system-x86_64 qemu-hw-display-virtio-vga qemu-img samba socat websocat 7zip jq coreutils \
  inotify-tools \
  aria2 wimlib cabextract bash chntpw cdrkit
COPY run.sh /run.sh
COPY win11-init /win11-init
ENTRYPOINT ["/run.sh"]
