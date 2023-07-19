#!/bin/ash
set -o errexit

# Create boot_disk image
if ! md5sum -s -c /cache/boot_disk.img.md5 2>/dev/null; then
  rm -f /cache/boot_disk.img
  echo -e "\033[32;49;1mBoot disk image is outdated, generating new one\033[0m"

  apk add --no-cache qemu-img mtools
  qemu-img create -f raw /cache/boot_disk.img 1440k
  mkfs.vfat /cache/boot_disk.img
  mcopy -i /cache/boot_disk.img /boot_disk/* ::
  md5sum /boot_disk/* > /cache/boot_disk.img.md5
fi

# Download virtio
if [ ! -f /cache/virtio-win.iso ]; then
  echo -e "\033[32;49;1mvirtio iso is missing, downloading\033[0m"
  apk add --no-cache aria2
  aria2c -x 5 -s 5 -d /cache -o virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
fi

# Download Windows 11 ISO
if [ ! -f /cache/win11.iso ]; then
  echo -e "\033[32;49;1mWindows 11 ISO is missing, downloading and building\033[0m"
  apk add --no-cache aria2 wimlib cabextract bash chntpw cdrkit

  aria2c --no-conf --dir /tmp/win11 --out aria-script --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_URL"
  aria2c --no-conf --dir /tmp/win11 --input-file /tmp/win11/aria-script --max-connection-per-server 16 --split 16 --max-concurrent-downloads 5 --continue --remote-time

  aria2c --no-conf --dir /tmp/win11 --out convert.sh --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_CONVERT_SCRIPT_URL"
  chmod +x /tmp/win11/convert.sh
  /tmp/win11/convert.sh wim /tmp/win11 0
  rm -rf /tmp/win11
  cd -

  mv /*PROFESSIONAL_X64_EN-US.ISO /cache/win11.iso
fi

# Build the Windows image
if [ ! -f /cache/win.qcow2 ]; then
  echo -e "\033[32;49;1mWindows 11 disk image is missing, going to install it now\033[0m"

  apk add --no-cache qemu-img samba
  rm -f /cache/win-building.qcow2

  echo -e "\033[32;32;1mCreating disk image\033[0m"
  qemu-img create -f qcow2 -o compression_type=zstd -q /cache/win-building.qcow2 30G

  if [ ! -e /dev/kvm ]; then
    echo -e "\033[31;49mKVM acceleration not found. Ensure you're using --device=/dev/kvm with docker.\033[0m"
    exit 1
  fi

  echo -e "\033[32;32;1mStarting qemu for installation\033[0m"
  echo -e "\033[32;49m(Watch using VNC on port 5950)\033[0m"

  trap 'echo -e "\033[31;49mTerminating\033[0m" ; rm -f /cache/win-building.qcow2' SIGINT SIGTERM

  # Set up direct logging with the console here. Use in Windows with: `echo hello >> \\10.0.2.4\qemu\status.txt`. Note
  # that you might need to run `wpeinit` if you're in the Windows installer.
  mkdir -p /tmp/qemu-status
  touch /tmp/qemu-status/status.txt
  tail -f /tmp/qemu-status/status.txt &

  CPU_COUNT=${CPU_COUNT:-$(grep -c ^processor /proc/cpuinfo)}
  MEMORY_GB=${MEMORY_GB:-8}
  qemu-system-x86_64 \
    -name arkalis-win \
    \
    -machine type=q35,accel=kvm \
    -rtc clock=host,base=localtime \
    -cpu host \
    -smp $CPU_COUNT \
    -m ${MEMORY_GB}G \
    -device virtio-balloon \
    -vga virtio \
    -device virtio-net,netdev=user.0 \
    -netdev user,id=user.0,hostfwd=tcp::3389-:3389,hostfwd=tcp::2222-:22 \
    -device qemu-xhci \
    -device usb-tablet,bus=usb-bus.0 \
    \
    -drive file=/cache/boot_disk.img,if=floppy,format=raw \
    -drive file=/cache/win-building.qcow2,media=disk,cache=unsafe,if=virtio,format=qcow2 \
    -drive file=/cache/win11.iso,media=cdrom \
    -drive file=/cache/virtio-win.iso,media=cdrom \
    -boot once=d \
    \
    -net user,smb=/tmp/qemu-status \
    -net nic,model=e1000 \
    -vnc 0.0.0.0:50
fi

echo -e "\033[32;49;1mDone!\033[0m"

#-nic 'user,id=n1,guestfwd=tcp:10.0.2.100:1234-cmd:cat > /tmp/out' \
#
#-device virtio-net,netdev=user.0 \
# # Run
# qemu-system-x86_64 \
#   -vnc 127.0.0.1:50 \
#   -netdev user,id=user.0,hostfwd=tcp::3389-:3389,hostfwd=tcp::2222-:22 \
#   -cpu host \
#   -machine type=q35,accel=kvm \
#   -m 8192M \
#   -smp 32 \
#   -vga virtio \
#   -name packer-qemu \
#   -device qemu-xhci \
#   -device usb-tablet,bus=usb-bus.0 \
#   -device virtio-net,netdev=user.0 \
#   -drive file=output/packer-qemu,if=virtio,cache=writeback,discard=ignore,format=qcow2

