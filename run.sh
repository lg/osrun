#!/bin/ash
#shellcheck shell=dash disable=SC3036,SC3048
set -o errexit

mkdir -p /tmp/qemu-status

start_qemu() {
  qemu-system-x86_64 \
    -name arkalis-win \
    \
    -machine type=q35,accel=kvm \
    -rtc clock=host,base=localtime \
    -cpu host \
    -smp "${CPU_COUNT:-$(grep -c ^processor /proc/cpuinfo)}" \
    -m "${MEMORY_GB:-8}G" \
    -device virtio-balloon \
    -vga virtio \
    -device e1000,netdev=user.0 \
    -netdev user,id=user.0,smb=/tmp/qemu-status \
    \
    -drive file=/cache/win.qcow2,media=disk,cache=unsafe,if=virtio,format=qcow2,discard=unmap \
    $1 \
    \
    -device qemu-xhci \
    -device usb-tablet,bus=usb-bus.0 \
    \
    -device virtio-serial \
    -chardev socket,websocket=on,host=0.0.0.0,port=44444,server=on,wait=off,id=qga0 \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    \
    -vnc 0.0.0.0:50 \
    -monitor tcp:0.0.0.0:55556,server=on,wait=off \
    &
}

if [ ! -f /cache/win.qcow2 ]; then
  echo -e "\033[32;49;1mWindows 11 disk image is missing, going to install it now\033[0m"

  if [ ! -f /cache/virtio-win.iso ]; then
    echo -e "\033[32;49;1mvirtio iso is missing, downloading\033[0m"
    aria2c -x 5 -s 5 -d /cache -o virtio-win.iso https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso
  fi

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

  if [ ! -f /cache/newwin11.iso ]; then
    echo -e "\033[32;49;1mAdding scripts and drivers to Windows 11 ISO\033[0m"
    mkdir -p /tmp/win11
    7z x /cache/win11.iso -o/tmp/win11
    7z x /cache/virtio-win.iso -o/tmp/win11/virtio
    cp /boot_disk/* /tmp/win11
    cd /tmp/win11
    genisoimage -b "boot/etfsboot.com" --no-emul-boot --eltorito-alt-boot -b "efi/microsoft/boot/efisys.bin" \
      --no-emul-boot --udf -iso-level 3 --hide "*" -V "WIN11" -o /cache/newwin11.iso .
    cd -
    rm -rf /tmp/win11
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
  start_qemu "-drive file=/cache/newwin11.iso,media=cdrom -boot once=d"
  wait "$!"
  if ! grep -q "Successfully provisioned image." /tmp/qemu-status/status.txt; then
    echo -e "\033[31;49mFailed to install Windows successfully, aborting\033[0m"
    kill -INT $$
  fi

  echo -e "\033[32;32;1mInitial provisioning completed, restarting to create snapshot\033[0m"
  MEMORY_GB=4
  start_qemu
  QEMU_PID="$!"

  echo -e "\033[32;49mWaiting for QEMU agent\033[0m"
  echo '{"execute": "guest-get-osinfo"}' | while ! websocat -b -n -1 ws://127.0.0.1:44444/; do sleep 1; done
  echo -e "\033[32;49mSleeping 10 seconds\033[0m"
  sleep 10
  echo -e "\033[32;49mCreating snapshot and waiting for QEMU to exit\033[0m"
  echo -e "savevm provisioned\nq" | nc 127.0.0.1 55556
  wait "$QEMU_PID"

  echo -e "\033[32;49;1mWindows installation complete\033[0m"
  trap - SIGINT SIGTERM
fi

echo -e "\033[32;49;1mLoading Windows snapshot\033[0m"
MEMORY_GB=4
start_qemu "-loadvm provisioned"
echo '{"execute": "guest-set-time"}' | while ! websocat -b -n -1 ws://127.0.0.1:44444/; do sleep 1; done

# echo "started and waiting"
# while ! [ -e /tmp/qemu-status/done.txt ]; do sleep 1; done
echo "done"
