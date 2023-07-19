#!/bin/ash
set -o errexit

# Create floppy image
if md5sum -s -c /cache/floppy.img.md5 2>/dev/null; then
  echo "Floppy image is up to date"
else
  echo "Floppy image is outdated, generating new one"
  apk add --no-cache mtools
  dd if=/dev/zero of=/cache/floppy.img bs=1M count=2
  mformat -i /cache/floppy.img ::
  mcopy -i /cache/floppy.img /floppy/* ::
  md5sum /floppy/* > /cache/floppy.img.md5
fi

# Download virtio
if [ ! -f /cache/virtio-win.iso ]; then
  echo "virtio iso is missing, downloading"
  apk add --no-cache aria2
  aria2c -x 5 -s 5 -d /cache -o virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
fi

# Download Windows 11 ISO
if [ ! -f /cache/win11.iso ]; then
  apk add --no-cache aria2 wimlib cabextract bash chntpw cdrkit
  echo "Windows 11 ISO is missing, downloading"
  aria2c --no-conf --dir /tmp/win11 --out aria-script --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_URL"
  aria2c --no-conf --dir /tmp/win11 --input-file /tmp/win11/aria-script --max-connection-per-server 16 --split 16 --max-concurrent-downloads 5 --continue --remote-time

  aria2c --no-conf --dir /tmp/win11 --out convert.sh --allow-overwrite=true --auto-file-renaming=false "$UUP_CONVERT_SCRIPT_URL"
  chmod +x /tmp/win11/convert.sh
  /tmp/win11/convert.sh wim /tmp/win11 0
  rm -rf /tmp/win11
  cd -

  bash

  mv /*PROFESSIONAL_X64_EN-US.ISO /cache/win11.iso
fi

echo "Ready!"


# # Create floppy image for installation config
# mkfs.msdos -C /tmp/packer2100503815 1440


# # Installation
# qemu-system-x86_64 \
#   -boot once=d \
#   -vnc 127.0.0.1:50 \
#   -netdev user,id=user.0,hostfwd=tcp::3389-:3389,hostfwd=tcp::2222-:22 \
#   -cpu host \
#   -machine type=q35,accel=kvm \
#   -m 8192M \
#   -smp 32 \
#   -fda /tmp/packer2100503815 \
#   -vga virtio \
#   -name packer-qemu \
#   -cdrom virtio-win.iso \
#   -device qemu-xhci \
#   -device usb-tablet,bus=usb-bus.0 \
#   -device virtio-net,netdev=user.0 \
#   -drive file=output/packer-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2 \
#   -drive file=/root/arkalis-win/Win11_22H2_English_x64v2.iso,media=cdrom

# # Run
qemu-system-x86_64 \
  -vnc 127.0.0.1:50 \
  -netdev user,id=user.0,hostfwd=tcp::3389-:3389,hostfwd=tcp::2222-:22 \
  -cpu host \
  -machine type=q35,accel=kvm \
  -m 8192M \
  -smp 32 \
  -vga virtio \
  -name packer-qemu \
  -device qemu-xhci \
  -device usb-tablet,bus=usb-bus.0 \
  -device virtio-net,netdev=user.0 \
  -drive file=output/packer-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2

