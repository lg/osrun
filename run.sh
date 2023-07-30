#!/bin/ash
#shellcheck shell=dash disable=SC3036,SC3048
set -o errexit -o noclobber -o nounset -o pipefail

# Parse commandline arguments
usage() {
  echo -e "\
  Usage: osrun [-v] [-h] <command>\n\
  Installs Windows 11 and runs commands in a VM.\n\n\
  -v --verbose: Verbose mode (useful while installing)\n\
  -p --pause: Do not close the VM after the command finishes\n\
  -h --help: Display this help" 1>&2
  exit 1
}; [ $# -eq 0 ] && usage

VERBOSE=false
PAUSE=false
params="$(getopt -o vhp -l verbose,help,pause -n "osrun" -- "$@")"
eval set -- "$params"
while true; do case "$1" in
  -v|--verbose) VERBOSE=true; shift ;;
  -p|--pause) PAUSE=true; shift ;;
  --) shift; break ;;
  *) usage ;;
esac; done

shift
RUN_COMMAND="$*"

[ ! -e /dev/kvm ] && echo -e "\033[33;49;1mKVM acceleration not found. Ensure you're using --device=/dev/kvm with docker.\033[0m"

# Windows 11 from May 2023, go to https://uupdump.net and get the link to the latest Retail Windows 11
UUPDUMP_URL="http://uupdump.net/get.php?id=3a34d712-ee6f-46fa-991a-e7d9520c16fc&pack=en-us&edition=professional&aria2=2"
UUPDUMP_CONVERT_SCRIPT_URL="https://github.com/uup-dump/converter/raw/073071a0003a755233c2fa74c7b6173cd7075ed7/convert.sh"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
INSTALL_MEMORY_GB=8
RUN_MEMORY_GB=4
DEFAULT_VOLUME_PATH="/cache/win11.qcow2"

mkdir -p /tmp/qemu-status

start_qemu() {
  VOLUME_PATH="$DEFAULT_VOLUME_PATH"
  while getopts 'm:o:v:' OPTION; do case "$OPTION" in
    m) MEMORY_GB="$OPTARG" ;;
    o) QEMU_OPTS="$OPTARG" ;;
    v) VOLUME_PATH="$OPTARG" ;;
    *) exit 1 ;;
  esac; done
  qemu-system-x86_64 \
    -name osrun \
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
    -drive file=$VOLUME_PATH,media=disk,cache=unsafe,if=virtio,format=qcow2,discard=unmap \
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
    -monitor tcp:0.0.0.0:55556,server=on,wait=off \
    &
  #
}

agent_command() {
  local val; local execute; local arguments
  execute="$1"; arguments="${2:-"{}"}"
  val=$(echo "{\"execute\": \"$execute\", \"arguments\": $arguments}" \
    | while ! websocat -b -n -1 ws://127.0.0.1:44444/ 2>/dev/null; do sleep 0.1; done)

  if [ "$(echo "$val" | jq -r '.error')" != null ]; then
    echo -e "\033[31;49mError running $execute$([ "$arguments" != "{}" ] && echo " ($arguments)"): $(\
      echo "$val" | jq -r '.error.desc')\033[0m"
    exit 1
  fi
  echo "$val" | jq -r '.return'
}

if [ ! -e /cache/win11.qcow2 ]; then
  echo -e "\033[32;49;1mWindows 11 disk image is missing, going to install it now\033[0m"
  mkdir -p /root/.aria2/ ; echo -e "console-log-level=warn\nmax-connection-per-server=16\nsplit=16\n\
    max-concurrent-downloads=5\ncontinue\nremote-time\nauto-file-renaming=false\n" > "/root/.aria2/aria2.conf"

  if [ ! -e /cache/win11-clean.iso ]; then
    echo -e "\033[32;49;1mDownloading Windows 11 from Windows Update\033[0m"
    mkdir -p /tmp/win11
    aria2c --dir /tmp/win11 --out aria-script --allow-overwrite=true "$UUPDUMP_URL"
    aria2c --dir /tmp/win11 --input-file /tmp/win11/aria-script
    aria2c --dir /tmp/win11 --out convert.sh --allow-overwrite=true "$UUPDUMP_CONVERT_SCRIPT_URL"
    chmod +x /tmp/win11/convert.sh

    echo -e "\033[32;49;1mBuilding Windows 11 ISO\033[0m"
    /tmp/win11/convert.sh wim /tmp/win11 0
    mv /*PROFESSIONAL_X64_EN-US.ISO /cache/win11-clean.iso
    rm -rf /tmp/win11
  fi

  if [ ! -e /cache/win11-prepared.iso ]; then
    echo -e "\033[32;49;1mDownloading virtio drivers and embedding them and init scripts Windows installer\033[0m"
    mkdir -p /tmp/win11
    aria2c --dir /tmp --out virtio-win.iso "$VIRTIO_URL"
    7z x /cache/win11-clean.iso -o/tmp/win11
    7z x /tmp/virtio-win.iso -o/tmp/win11/virtio
    cp /win11-init/* /tmp/win11
    cd /tmp/win11
    genisoimage -quiet -b "boot/etfsboot.com" --no-emul-boot --eltorito-alt-boot -b "efi/microsoft/boot/efisys.bin" \
      --no-emul-boot --udf -iso-level 3 --hide "*" -V "WIN11" -o /cache/win11-prepared.iso .
    cd -
    rm -rf /tmp/win11
  fi

  echo -e "\033[32;32;1mInstalling Windows (Logs redirected here, VNC 5950, QEMU Monitor 55556, QEMU Agent 44444)\033[0m"

  # Set up direct logging with the console here. Use in Windows with: `echo hello >> \\10.0.2.4\qemu\status.txt`. Note
  # that you might need to run `wpeinit` if you're in the Windows installer to start networking.
  mkdir -p /tmp/qemu-status
  touch /tmp/qemu-status/status.txt
  tail -f /tmp/qemu-status/status.txt &

  if [ ! -e /cache/win11-installercopied.qcow2 ]; then
    echo -e "\033[32;32;1mCreating temp disk image\033[0m"
    trap 'echo -e "\033[31;49mTerminating\033[0m" ; rm -f /cache/win11-installercopied.qcow2 ; exit 1' SIGINT SIGTERM
    qemu-img create -f qcow2 -o compression_type=zstd -q /cache/win11-installercopied.qcow2 15G

    echo -e "\033[32;32mBooting into Windows Setup\033[0m"
    start_qemu -m $INSTALL_MEMORY_GB -o "-drive file=/cache/win11-prepared.iso,media=cdrom -action reboot=shutdown" \
      -v "/cache/win11-installercopied.qcow2"
    wait "$!"
    trap - SIGINT SIGTERM
  fi

  trap 'echo -e "\033[31;49mTerminating\033[0m" ; rm -f /cache/win11.qcow2 ; exit 1' SIGINT SIGTERM
  if [ ! -e /cache/win11.qcow2 ]; then
    echo -e "\033[32;32mRunning installation scripts\033[0m"
    cp /cache/win11-installercopied.qcow2 /cache/win11.qcow2
    start_qemu -m $INSTALL_MEMORY_GB -o "-drive file=/cache/win11-prepared.iso,media=cdrom" -v "/cache/win11.qcow2"
    wait "$!"
  fi

  if ! grep -q "Successfully provisioned image." /tmp/qemu-status/status.txt; then
    echo -e "\033[31;49mFailed to install Windows successfully, aborting\033[0m"
    kill -INT $$
  fi

  echo -e "\033[32;32mCreating VM snapshot\033[0m"
  start_qemu -m $RUN_MEMORY_GB
  QEMU_PID=$!
  agent_command guest-get-osinfo
  sleep 10
  echo -e "savevm provisioned\nq" | nc 127.0.0.1 55556
  wait "$QEMU_PID"

  echo -e "\033[32;49mWindows installation complete\033[0m"
  trap - SIGINT SIGTERM
  rm -f /cache/win11-prepared.iso /cache/win11-installedcopied.qcow2 /cache/win11-clean.iso
fi

$VERBOSE && echo -e "\033[32;49;1mRunning \`$RUN_COMMAND\`\033[0m"
echo -e "@ECHO OFF\nECHO OFF\n\n$RUN_COMMAND\n" > /tmp/qemu-status/run.cmd

$VERBOSE && echo -e "\033[32;49mRestoring snapshot\033[0m"
mkdir -p /tmp/qemu-status/done; touch /tmp/qemu-status/out.txt
start_qemu -m $RUN_MEMORY_GB -o "-loadvm provisioned"

# Since we resume a snapshot, we need to update the clock
agent_command guest-exec "{'path': 'cmd', 'arg': ['/c', 'powershell Set-Date \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\" & \
  echo done > //10.0.2.4/qemu/done/done.txt']}" > /dev/null
inotifywait -q -e create /tmp/qemu-status/done > /dev/null
rm -f /tmp/qemu-status/done/done.txt

$VERBOSE && echo -e "\033[32;49mRunning command\033[0m"
EXEC_START=$(agent_command guest-exec '{"path": "cmd",
  "arg": ["/c", "//10.0.2.4/qemu/run.cmd >>//10.0.2.4/qemu/out.txt 2>&1 & echo done > //10.0.2.4/qemu/done/done.txt"]}')
PROCESS_PID=$(echo "$EXEC_START" | jq -r '.pid')

$VERBOSE && echo -e "\033[32;49mWaiting for command to complete\033[0m"
inotifywait -q -e create /tmp/qemu-status/done > /dev/null &
tail -f /tmp/qemu-status/out.txt --pid "$!"   # using inotify manually since tail for alpine doesn't seem to use it

# for faster docker shutdown, intentionally not cleaning up: qemu and the /tmp/qemu-status files
$PAUSE && echo -e "\033[32;49mPausing as requested\033[0m" && read -r
EXEC_STATUS=$(agent_command guest-exec-status '{"pid": '"$PROCESS_PID"'}')
exit "$(echo "$EXEC_STATUS" | jq -r '.exitcode')"
