# osrun

A docker container to run Windows commands and processes. On first run it will generate a Windows 11 ISO and run a VM to install it and create a system snapshot. On subsequent runs it will use the existing cached VM image to run the command passed in. noVNC is available on port 8000 (when forwarded via Docker) to view the VM's display.

## Usage

```bash
# Linux
docker run -it --rm --device=/dev/kvm -v $(pwd)/cache:/cache ghcr.io/lg/osrun 'dir "C:\Program Files"'

# MacOS (installation will be very slow)
docker run -it --rm -v $(pwd)/cache:/cache ghcr.io/lg/osrun 'dir "C:\Program Files"'
```
<pre style="font-size: small">
 Volume in drive C is Windows 11
 Volume Serial Number is F48D-7158

 Directory of C:\Program Files

08/06/2023  09:24 PM    &lt;DIR&gt;          .
05/06/2022  10:42 PM    &lt;DIR&gt;          Common Files
05/07/2022  12:38 AM    &lt;DIR&gt;          Internet Explorer
...
</pre>

```text
Usage: osrun [flags] '<command>'
Short-lived containerized Windows instances

  -h --help: Display this help
  -v --verbose: Verbose mode (default: false)

Install
  -k --keep: Keep install artifacts after successful provisioning (default: false)

Run
  -p --pause: Do not close the VM after the command finishes (default: false)
  -n --new-snapshot <name>: Generate a new snapshot after the command finishes
  -s --use-snapshot <name>: Restore from the specified snapshot (default: provisioned)
```

## Developing

```bash
# Build the container
docker build -t osrun .

# Install Windows and run a command
docker run -it --rm --device=/dev/kvm -v $(pwd)/cache:/cache -p 8000:8000 osrun -k -v -p 'dir "C:\Program Files"'
```

This project is intended to be developed inside of VSCode. Because the KVM acceleration is substantial, it's suggested that you either run things on a Linux machine or use VSCode's Remote functionality to remotely develop on a Linux machine (and port forward port 8000 for noVNC).

## Protips

- **Don't forget to mount the cache directory in Docker and passthrough kvm**
- Use single quotes around the run command to avoid shell expansion. There is no need for double backslashes in Windows paths. Ex: `osrun 'dir "C:\Program Files"'`.
- Take advantage of noVNC, `--verbose` and `--pause` to debug installation/execution
- Enable auto-reconnect on noVNC and also use "Local Scaling" and "Show Dot when No Cursor"
- You can inspect the container state using `docker exec -it <container-id> ash`.
- You can enter the QEMU Monitor using `docker exec -it <container-id> socat tcp:127.0.0.1:55556 readline` or just `socat tcp:127.0.0.1:55556 readline` locally if you forwarded the port.

## Details

This container uses [QEMU](https://www.qemu.org/) to run a Windows 11 VM. Windows 11 is built with the file list from [UUP dump](https://uupdump.net/) (or a backup server) and files are downloaded directly from Microsoft's Windows Update servers. The [UUP dump script](https://github.com/uup-dump/converter) generates a Windows ISO into which we then add an `autounattend.xml` script to start the installation automation. To keep the resultant VM small (~6GB) and fast we remove a lot of the default Windows components and services including Windows Defender, Windows Update, Edge, most default apps, and also disable things like paging, sleep and hibernation, plus the hard drive is compressed and trimmed. This process is done by the files in the `win11-init` directory. This image and VM state is then snapshotted when the system is stable and is saved to a cache directory so that subsequent runs start quickly.

On a reasonably modern machine the installation process takes about 20 minutes end-to-end and runs take about 3-4 seconds for simple commands like `dir`. Without KVM expect the installation to take about 2-3 hours and runs to take about 30 seconds even on fast machines like the M2 Macs.

```mermaid
flowchart LR
  subgraph Z["Installer preparation"]
    A["Windows Setup file-list assembled"]
    -->
    A1["UUPDump script generates Setup ISO"]
    -->
    A2["autounattend.xml injected into ISO"]
    --"win11-clean.iso artifact prepared"-->
    A3["QEMU mounts ISO and starts VM"]
  end

  subgraph ZA["Installation process"]
    B-1["noVNC started on port 8000 for debugging"]
    -->
    B["Setup runs autounattend.xml"]
    --Artifact saved: /cache/win11-step0-HASH.qcow2-->
    B1["boot-0.ps1 as NT AUTHORITY/SYSTEM"]
    --Artifact saved: /cache/win11-step1-HASH.qcow2-->
    B2["boot-1.ps1 as Administrator"]
    --Artifact saved: /cache/win11-step2-HASH.qcow2-->
    B2.1["Artifacts joined and compressed into /cache/win11.qcow2"]
    -->
    B3["QEMU Agent waits for boot with /tmp/qemu-status/bootlog.txt"]
    --'provisioned' snapshot saved to /cache/win11.qcow2\nAll other artifacts removed-->
    B4["Ready to run"]
  end

  subgraph ZB["Running"]
    C["Command written to /tmp/qemu-status/run.cmd"]
    -->
    C0["noVNC started on port 8000 for debugging"]
    -->
    C1["QEMU snapshot restored"]
    --/tmp/qemu-status mounted as \\10.0.2.4\QEMU in Windows-->
    C2["Clock set to proper time using QEMU Agent"]
    --inotify triggered on /tmp/qemu-status/done-->
    C3["Command executed using QEMU Agent"]
    --/tmp/qemu-status/out.txt tailed for output \nuntil inotify triggered on /tmp/qemu-status/done-->
    C4["New snapshot optionally created via QEMU Monitor"]
    -->
    C5["Exit code returned"]
  end

  Z-->ZA
  ZA-->ZB
```

Communication between the QEMU VM and the Docker container is done via the QEMU Agent and a QEMU-started Samba server (available in the host container in `/tmp/qemu-status` or in the VM in `\\10.0.2.4\qemu`). During installation and execution, multiple debugging services are started (you'll need to forward these ports using Docker if you want to use them outside the container):
- a noVNC HTTP server is started on port `8000` to view the VM's display,
- the raw QEMU-run VNC server is also available on port `5950` (not compatible with Apple Screen Sharing) if you don't prefer noVNC,
- the QEMU Monitor (ie. command-line interface) is available on port `55556` (supported commands are [here](https://qemu-project.gitlab.io/qemu/system/monitor.html)), and
- the QEMU Guest Agent is available on port `44444` (its JSON protocol is [here](https://qemu.readthedocs.io/en/latest/interop/qemu-ga-ref.html)).

```mermaid
flowchart LR
  subgraph "Host machine"
    subgraph "Docker Container"
      subgraph "QEMU VM"
        A[["\\10.0.2.4\qemu"]]
        D["virtio display"]
        I["QEMU Agent"]
        A<--When installing---O[["\\10.0.2.4\qemu\status.txt<br/>\\10.0.2.4\qemu\bootlog.txt"]]
        A<--When running---P[["\\10.0.2.4\run.cmd<br/>\\10.0.2.4\qemu\out.txt<br/>\\10.0.2.4\qemu\done"]]
      end

      A<-->B[["/tmp/qemu-status"]]
      D-->E["QEMU VNC server"]
      G["QEMU Monitor"]
      K[["/cache"]]
      L[["/win11-init/*.ps1"]]-.Mounted into on install.->A
      E-.Port 5950.->R["HTTP server w/ websockets proxy"]
    end


    R-.Port 8000.->Q["noVNC HTTP frontend"]
    E-.Port 5950.->F["VNC client"]
    G-.Port 55556.->H["QEMU Monitor client"]
    I-.Port 44444.->J["QEMU Agent client"]
    K--Docker Volume-->M[["Directory"]]
  end
```

### The `--new-snapshot` and `--use-snapshot` flags

While the final image will always have a `provisioned` snapshot, you can create new snapshots from the VM end-state of your command using the `--new-snapshot <name>` flag. You can then use this snapshot for subsequent runs using the `--use-snapshot <name>` flag. This is useful if you need to change the VM's configuration or install a tool on top of the base `provisioned` snapshot. Behind the scenes this uses the `savevm` and `loadvm` commands on the QEMU Monitor protocol which snapshots memory and disk state into the main `qcow2` image.

As an example (in order):

1. `osrun --new-snapshot greeted 'mkdir C:\hello'`
    ```mermaid
    flowchart LR
      A["'provisioned' snapshot restored"]
      -->B["mkdir executed"]
      -->C["New 'greeted' snapshot created"]
    ```

2. `osrun --use-snapshot greeted 'dir C:\'`
    ```mermaid
    flowchart LR
      A["'greeted' snapshot restored"]
      -->B["dir executed, will display the 'hello' directory"]
    ```

3. `osrun 'dir C:\'`
    ```mermaid
    flowchart LR
      A["'provisioned' snapshot restored"]
      -->B["dir executed, will not display the 'hello' directory"]
    ```

### TODO

- [ ] Pipe errors into the output
- [ ] Add support for Windows 10 / MacOS
- [ ] Figure out if hvf acceleration is at all possible for MacOS
- [ ] Support stdin into the VM
