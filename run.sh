#!/bin/ash
#shellcheck shell=dash disable=SC3036,SC3048,SC2002
set -o errexit -o noclobber -o nounset -o pipefail

# Parse commandline arguments
usage() {
  echo -e \
    "Usage: osrun [-v] [-h] <command>\n" \
    "Installs Windows 11 and runs commands in a VM.\n" \
    "\n" \
    "  -h --help: Display this help\n" \
    "  -v --verbose: Verbose mode\n" \
    "\n" \
    "Install\n" \
    "  -k --keep: Keep the installation ISOs after successful provisioning\n" \
    "\n" \
    "Run\n" \
    "  -p --pause: Do not close the VM after the command finishes\n" \
    1>&2

  exit 1
}; [ $# -eq 0 ] && usage

VERBOSE=false; PAUSE=false; KEEP_INSTALL_FILES=false
params="$(getopt -o vhpk -l verbose,help,pause,keep -n "osrun" -- "$@")"
eval set -- "$params"
while true; do case "$1" in
  -k|--keep) KEEP_INSTALL_FILES=true; shift ;;
  -v|--verbose) VERBOSE=true; shift ;;
  -p|--pause) PAUSE=true; shift ;;
  --) shift; break ;;
  *) usage ;;
esac; done

RUN_COMMAND="$*"

# Windows 11 from May 2023, go to https://uupdump.net and get the link to the latest Retail Windows 11
UUPDUMP_URL="http://uupdump.net/get.php?id=3a34d712-ee6f-46fa-991a-e7d9520c16fc&pack=en-us&edition=professional&aria2=2"
UUPDUMP_CONVERT_SCRIPT_URL="https://github.com/uup-dump/converter/raw/073071a0003a755233c2fa74c7b6173cd7075ed7/convert.sh"
INSTALL_MEMORY_GB=8
RUN_MEMORY_GB=4

# Everything logged to /tmp/qemu-status/status.txt or in Windows with `echo hello >> \\10.0.2.4\qemu\status.txt` will be
# printed out to stdout
mkdir -p /tmp/qemu-status
touch /tmp/qemu-status/status.txt
tail -f /tmp/qemu-status/status.txt &

start_qemu() {
  KVM_PARAM=",accel=kvm"; CPU_PARAM="-cpu host"
  if [ ! -e /dev/kvm ]; then
    echo -e "\033[33;49mKVM acceleration not found. Ensure you're using --device=/dev/kvm with docker. Virtualization will be very slow.\033[0m" > /dev/stderr
    KVM_PARAM=""; CPU_PARAM="-accel tcg"
  fi

  QEMU_OPTS=""
  while getopts 'rm:o:v:' OPTION; do case "$OPTION" in
    m) MEMORY_GB="$OPTARG" ;;
    o) QEMU_OPTS="$OPTARG" ;;
    v) VOLUME_PATH="$OPTARG" ;;
    *) exit 1 ;;
  esac; done
  qemu-system-x86_64 \
    -name osrun \
    \
    -machine "type=q35$KVM_PARAM" \
    -rtc clock=host,base=localtime \
    $CPU_PARAM \
    -smp "$(grep -c ^processor /proc/cpuinfo)" \
    -m "${MEMORY_GB:-8}G" \
    -vga virtio \
    -device e1000,netdev=user.0 \
    -netdev user,id=user.0,smb=/tmp/qemu-status \
    \
    -drive "file=$VOLUME_PATH,media=disk,cache=unsafe,if=ide,format=qcow2,discard=unmap" \
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

  echo -e "\033[32;49;1mGenerating ISO for autounattend.xml\033[0m"
  genisoimage -joliet -o "/tmp/autounattend.iso" -quiet /win11-init/autounattend.xml

  echo -e "\033[32;32;1mInstalling Windows (Logs redirected here, VNC 5950, QEMU Monitor 55556, QEMU Agent 44444)\033[0m"
  mkdir -p /tmp/qemu-status/win11-init
  cp /win11-init/* /tmp/qemu-status/win11-init/

  # The Windows installation will reboot a variety of times. This will keep the hard drive state for each reboot so you
  # can edit the scripts and re-run the installation without having to start from scratch.
  INIT_SCRIPTS_PATH="./win11-init"
  STEP_FILES="autounattend.xml boot-0.ps1 boot-1.ps1"
  for STEP in 0 1 2; do
    STEP_FILENAME=$(echo "$STEP_FILES" | cut -d' ' -f$((STEP+1)))
    STEP_HASH=$(echo "${PREV_STEP_HASH:-""}$(cat "$INIT_SCRIPTS_PATH/$STEP_FILENAME")" | md5sum | cut -c1-5 )
    STEP_ARTIFACT="/cache/win11-step$STEP-$STEP_HASH.qcow2"
    echo -e "\033[32;32mBooting, will use script $STEP_FILENAME, artifact will be: $STEP_ARTIFACT\033[0m"

    if [ ! -e "$STEP_ARTIFACT" ]; then
      rm -f /cache/win11-step$STEP-*.qcow2          # remove any previous artifacts for this step
      if [ "$STEP" = "0" ]; then
        qemu-img create -f qcow2 -o compression_type=zstd -q "$STEP_ARTIFACT" 15G
      else
        cp "$PREV_STEP_ARTIFACT" "$STEP_ARTIFACT"
      fi

      trap 'echo -e "\033[31;49mRemoving incomplete artifact $STEP_ARTIFACT\033[0m" ; rm -f "$STEP_ARTIFACT" ; exit 1' SIGINT SIGTERM
      start_qemu -m $INSTALL_MEMORY_GB -v "$STEP_ARTIFACT" -o "-action reboot=shutdown -drive file=/cache/win11-clean.iso,media=cdrom -drive file=/tmp/autounattend.iso,media=cdrom"
      wait "$!" || kill -SIGINT $$
      trap - SIGINT SIGTERM
    fi

    PREV_STEP_ARTIFACT="$STEP_ARTIFACT"
    PREV_STEP_HASH="$STEP_HASH"
  done

  trap 'echo -e "\033[31;49mRemoving /cache/win11.qcow2\033[0m" ; rm -f /cache/win11.qcow2 ; exit 1' SIGINT SIGTERM
  echo -e "\033[32;32;1mCreating VM snapshot\033[0m"
  cp "$PREV_STEP_ARTIFACT" /cache/win11.qcow2
  start_qemu -m $RUN_MEMORY_GB -v /cache/win11.qcow2
  QEMU_PID="$!"
  echo -e "\033[32;32mWaiting for VM to boot one last time\033[0m"
  agent_command guest-info > /dev/null
  sleep 5
  echo -e "\033[32;32mCreating snapshot and waiting for VM to stop\033[0m"
  echo -e "savevm provisioned\nq" | nc 127.0.0.1 55556
  wait "$QEMU_PID" || kill -SIGINT $$

  echo -e "\033[32;32;1mWindows installation complete\033[0m"
  trap - SIGINT SIGTERM
  ! $KEEP_INSTALL_FILES && rm -f /cache/win11-*
fi

# The command is written to /tmp/qemu-status/run.cmd such that we don't need to worry about escaping quotes and such.
# We use the "provisioned" snapshot stored in the qcow2 file to avoid having to wait for Windows to boot
$VERBOSE && echo -e "\033[32;49;1mRunning \`$RUN_COMMAND\`\033[0m"
$VERBOSE && echo -e "\033[32;49mRestoring snapshot\033[0m"
echo -e "@ECHO OFF\nECHO OFF\n" > /tmp/qemu-status/run.cmd
echo "$RUN_COMMAND" >> /tmp/qemu-status/run.cmd
start_qemu -m $RUN_MEMORY_GB -o "-loadvm provisioned" -v /cache/win11.qcow2

# Since we resume a snapshot, we need to update the clock. Note we wait for a 'done' file to be created in the shared
# network drive to signal that a command has completed.
mkdir -p /tmp/qemu-status/done
agent_command guest-exec "{'path': 'cmd', 'arg': ['/c', 'powershell Set-Date \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\" & \
  echo done > //10.0.2.4/qemu/done/done.txt']}" > /dev/null
inotifywait -q -e create /tmp/qemu-status/done > /dev/null
rm -f /tmp/qemu-status/done/done.txt

$VERBOSE && echo -e "\033[32;49mRunning command\033[0m"
touch /tmp/qemu-status/out.txt
inotifywait -q -e create /tmp/qemu-status/done > /dev/null &
DONE_WATCHER_PID=$!
EXEC_START=$(agent_command guest-exec '{"path": "cmd",
  "arg": ["/c", "//10.0.2.4/qemu/run.cmd >>//10.0.2.4/qemu/out.txt 2>&1 & echo done > //10.0.2.4/qemu/done/done.txt"]}')
PROCESS_PID=$(echo "$EXEC_START" | jq -r '.pid')

# Since inotifywait was launched asynchronously, use the pid (when terminated) as the signal for `tail` below to end.
# This tail displays the output of the command.
$VERBOSE && echo -e "\033[32;49mWaiting for command to complete\033[0m"
tail -n +0 -f /tmp/qemu-status/out.txt --pid "$DONE_WATCHER_PID"

while true; do  # also ensure the pid ends (so we get the exit code)
  EXEC_STATUS=$(agent_command guest-exec-status '{"pid": '"$PROCESS_PID"'}')
  [ "$(echo "$EXEC_STATUS" | jq -r '.exited')" = "true" ] && break
  sleep 0.1
done
$PAUSE && echo -e "\033[32;49mPausing as requested (press ENTER to exit)\033[0m" && read -r

# for faster docker shutdown, intentionally not cleaning up: qemu and the /tmp/qemu-status files
exit "$(echo "$EXEC_STATUS" | jq -r '.exitcode')"
