#!/bin/ash
#shellcheck shell=dash disable=SC3036,SC3048
set -o errexit

start_qemu() {
  CPU_COUNT=${CPU_COUNT:-$(grep -c ^processor /proc/cpuinfo)}
  MEMORY_GB=${MEMORY_GB:-8}

  qemu-system-x86_64 \
    -name arkalis-win \
    \
    -machine type=q35,accel=kvm \
    -rtc clock=host,base=localtime \
    -cpu host \
    -smp "$CPU_COUNT" \
    -m "${MEMORY_GB}G" \
    -device virtio-balloon \
    -vga virtio \
    -device e1000,netdev=user.0 \
    -netdev user,id=user.0,smb=/tmp/qemu-status \
    \
    -drive file=/cache/boot_disk.img,if=floppy,format=raw \
    -drive file=/cache/win.qcow2,media=disk,cache=unsafe,if=virtio,format=qcow2,discard=unmap \
    -drive file=/cache/win11.iso,media=cdrom \
    -drive file=/cache/virtio-win.iso,media=cdrom \
    -boot once=d \
    \
    -device qemu-xhci \
    -device usb-tablet,bus=usb-bus.0 \
    -vnc 0.0.0.0:50 \
    -monitor tcp:0.0.0.0:55556,server=on,wait=off \
    -device virtio-serial \
    -chardev socket,port=44444,host=0.0.0.0,server=on,wait=off,id=qga0 \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    &
}

# Build the Windows image
if [ ! -f /cache/win.qcow2 ]; then
  echo -e "\033[32;49;1mWindows 11 disk image is missing, going to install it now\033[0m"

  # Create boot_disk image
  echo -e "\033[32;49;1mGenerating boot driver disk\033[0m"
  rm -f /cache/boot_disk.img
  qemu-img create -f raw /cache/boot_disk.img 1440k
  mkfs.vfat /cache/boot_disk.img
  mcopy -i /cache/boot_disk.img /boot_disk/* ::

  # Download virtio
  if [ ! -f /cache/virtio-win.iso ]; then
    echo -e "\033[32;49;1mvirtio iso is missing, downloading\033[0m"
    aria2c -x 5 -s 5 -d /cache -o virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
  fi

  # Download Windows 11 ISO
  if [ ! -f /cache/win11.iso ]; then
    echo -e "\033[32;49;1mWindows 11 ISO is missing, downloading and building\033[0m"
    aria2c --no-conf --dir /tmp/win11 --out aria-script --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_URL"
    aria2c --no-conf --dir /tmp/win11 --input-file /tmp/win11/aria-script --max-connection-per-server 16 --split 16 --max-concurrent-downloads 5 --continue --remote-time

    aria2c --no-conf --dir /tmp/win11 --out convert.sh --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_CONVERT_SCRIPT_URL"
    chmod +x /tmp/win11/convert.sh
    /tmp/win11/convert.sh wim /tmp/win11 0
    rm -rf /tmp/win11
    cd -

    mv /*PROFESSIONAL_X64_EN-US.ISO /cache/win11.iso
  fi

  echo -e "\033[32;32;1mCreating disk image\033[0m"
  qemu-img create -f qcow2 -o compression_type=zstd -q /cache/win.qcow2 15G

  if [ ! -e /dev/kvm ]; then
    echo -e "\033[31;49mKVM acceleration not found. Ensure you're using --device=/dev/kvm with docker.\033[0m"
    exit 1
  fi

  trap 'echo -e "\033[31;49mTerminating\033[0m" ; rm -f /cache/win.qcow2 ; exit 1' SIGINT SIGTERM

  # Set up direct logging with the console here. Use in Windows with: `echo hello >> \\10.0.2.4\qemu\status.txt`. Note
  # that you might need to run `wpeinit` if you're in the Windows installer.
  mkdir -p /tmp/qemu-status
  touch /tmp/qemu-status/status.txt
  tail -f /tmp/qemu-status/status.txt &

  echo -e "\033[32;32;1mStarting qemu for installation\033[0m"
  echo -e "\033[32;49m(Logs redirected here -- VNC 5950, QEMU Monitor 55556, QEMU Agent 44444, ex: \"socat tcp:127.0.0.1:55556 readline\")\033[0m"
  start_qemu

  while ! grep -q "Successfully provisioned image." /tmp/qemu-status/status.txt; do sleep 1; done
  echo -e "savevm provisioned\nq" | socat tcp:127.0.0.1:44444 -

  echo -e "\033[32;49;1mWindows installation complete\033[0m"
fi

