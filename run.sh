#!/bin/ash
#shellcheck shell=dash disable=SC3036,SC3048
set -o errexit

while getopts 'c:' OPTION; do case "$OPTION" in
  c) RUN_COMMAND="$OPTARG" ;;
  *) exit 1 ;;
esac; done

[ ! -e /dev/kvm ] && echo -e "\033[33;49;1mKVM acceleration not found. Ensure you're using --device=/dev/kvm with docker.\033[0m"

# Windows 11 from May 2023, go to https://uupdump.net and get the link to the latest Retail Windows 11
UUPDUMP_URL="http://uupdump.net/get.php?id=3a34d712-ee6f-46fa-991a-e7d9520c16fc&pack=en-us&edition=professional&aria2=2"
UUPDUMP_CONVERT_SCRIPT_URL="https://github.com/uup-dump/converter/raw/073071a0003a755233c2fa74c7b6173cd7075ed7/convert.sh"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
INSTALL_MEMORY_GB=8
RUN_MEMORY_GB=4

mkdir -p /tmp/qemu-status

start_qemu() {
  while getopts 'm:o:' OPTION; do case "$OPTION" in
    m) MEMORY_GB="$OPTARG" ;;
    o) QEMU_OPTS="$OPTARG" ;;
    *) exit 1 ;;
  esac; done
  qemu-system-x86_64 \
    -deamonize \
    -name arkalis-win \
    \
    -machine type=q35,accel=kvm \
    -rtc clock=host,base=localtime \
    -cpu host \
    -smp "$(grep -c ^processor /proc/cpuinfo)" \
    -m "${MEMORY_GB:-8}G" \
    -device virtio-balloon \
    -vga virtio \
    -device e1000,netdev=user.0 \
    -netdev user,id=user.0,smb=/tmp/qemu-status \
    \
    -drive file=/cache/win.qcow2,media=disk,cache=unsafe,if=virtio,format=qcow2,discard=unmap \
    $QEMU_OPTS \
    \
    -device qemu-xhci \
    -device usb-tablet,bus=usb-bus.0 \
    \
    -device virtio-serial \
    -chardev socket,websocket=on,host=0.0.0.0,port=44444,server=on,wait=off,id=qga0 \
    -device virtserialport,chardev=qga0,name=org.qemu.guest_agent.0 \
    \
    -vnc 0.0.0.0:50 \
    -monitor tcp:0.0.0.0:55556,server=on,wait=off
}

if [ ! -e /cache/win.qcow2 ]; then
  if [ ! -e /cache/win11-clean.iso ]; then
    echo -e "\033[32;49;1mWindows 11 disk image is missing, going to install it now\033[0m"
    echo -e "\033[32;49mDownloading and building Windows 11\033[0m"
    mkdir -p /tmp/win11
    aria2c --no-conf --dir /tmp/win11 --out aria-script --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_URL"
    aria2c --no-conf --dir /tmp/win11 --input-file /tmp/win11/aria-script --max-connection-per-server 16 --split 16 --max-concurrent-downloads 5 --continue --remote-time
    aria2c --no-conf --dir /tmp/win11 --out convert.sh --allow-overwrite=true --auto-file-renaming=false "$UUPDUMP_CONVERT_SCRIPT_URL"
    chmod +x /tmp/win11/convert.sh
    /tmp/win11/convert.sh wim /tmp/win11 0
    mv /*PROFESSIONAL_X64_EN-US.ISO /cache/win11-clean.iso
    rm -rf /tmp/win11
  fi

  if [ ! -e /cache/win11-prepared.iso ]; then
    echo -e "\033[32;49mDownloading virtio drivers and embedding them and init scripts Windows installer\033[0m"
    mkdir -p /tmp/win11
    aria2c -x 5 -s 5 -d /tmp -o virtio-win.iso "$VIRTIO_URL"
    7z x /cache/win11-clean.iso -o/tmp/win11
    7z x /tmp/virtio-win.iso -o/tmp/win11/virtio
    cp /win11-init/* /tmp/win11
    cd /tmp/win11
    genisoimage -b "boot/etfsboot.com" --no-emul-boot --eltorito-alt-boot -b "efi/microsoft/boot/efisys.bin" \
      --no-emul-boot --udf -iso-level 3 --hide "*" -V "WIN11" -o /cache/win11-prepared.iso .
    cd -
    rm -rf /tmp/win11
  fi

  echo -e "\033[32;32mCreating temp disk image\033[0m"
  qemu-img create -f qcow2 -o compression_type=zstd -q /cache/win.qcow2 15G

  echo -e "\033[32;32mInstalling Windows (Logs redirected here, VNC 5950, QEMU Monitor 55556, QEMU Agent 44444)\033[0m"
  trap 'echo -e "\033[31;49mTerminating\033[0m" ; rm -f /cache/win.qcow2 ; exit 1' SIGINT SIGTERM

  # Set up direct logging with the console here. Use in Windows with: `echo hello >> \\10.0.2.4\qemu\status.txt`. Note
  # that you might need to run `wpeinit` if you're in the Windows installer to start networking.
  mkdir -p /tmp/qemu-status
  touch /tmp/qemu-status/status.txt
  tail -f /tmp/qemu-status/status.txt &

  start_qemu -m $INSTALL_MEMORY_GB -o "-drive file=/cache/win11-prepared.iso,media=cdrom -boot once=d"
  wait "$!"
  if ! grep -q "Successfully provisioned image." /tmp/qemu-status/status.txt; then
    echo -e "\033[31;49mFailed to install Windows successfully, aborting\033[0m"
    kill -INT $$
  fi

  echo -e "\033[32;32mCreating VM snapshot\033[0m"
  start_qemu -m $RUN_MEMORY_GB
  QEMU_PID="$!"
  echo '{"execute": "guest-get-osinfo"}' | while ! websocat -b -n -1 ws://127.0.0.1:44444/; do sleep 1; done
  sleep 10
  echo -e "savevm provisioned\nq" | nc 127.0.0.1 55556
  wait "$QEMU_PID"

  echo -e "\033[32;49mWindows installation complete\033[0m"
  trap - SIGINT SIGTERM
  rm -f /cache/win11-clean.iso /cache/win11-prepared.iso
fi

echo -e "\033[32;49;1mRunning \`$RUN_COMMAND\`\033[0m"
start_qemu -m $RUN_MEMORY_GB -o "-loadvm provisioned"

PROCESS_PID=$(echo "{\"execute\": \"guest-exec\", \"args\": {\"path\": \"cmd\", \"arg\": [\"/c\", \"$RUN_COMMAND\"]}}" \
  | while ! websocat -b -n -1 ws://127.0.0.1:44444/; do sleep 1; done \
  | jq -r '.pid')

EXITED="false"
while [ "$EXITED" != "true" ]; do
  sleep 1
  EXEC_STATUS=$(echo "{\"execute\": \"guest-exec-status\", \"args\": {\"pid\": $PROCESS_PID\"}}" \
    | websocat -b -n -1 ws://127.0.0.1:44444/)
  EXITED=$(echo "$EXEC_STATUS" | jq -r '.exited')
  EXIT_CODE=$(echo "$EXEC_STATUS" | jq -r '.exitcode')
done

exit "$EXIT_CODE"
