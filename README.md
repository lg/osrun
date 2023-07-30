# osrun

A docker container to run a command in Windows 11 (via QEMU). On first run it will generate a Windows 11 ISO and run a VM to install it and create a system snapshot. On subsequent runs it will use the existing cached VM image.

## Usage

```bash
docker run -it --rm docker --device=/dev/kvm -v $(pwd)/cache:/cache osrun 'dir c:\windows\system32'
```

If you don't have kvm on your machine, you can skip the parameter, but things will be a lot slower. This mode is currently unreliable and may freeze during Windows 11 installation.

## Details

This container uses [QEMU](https://www.qemu.org/) to run a Windows 11 VM. Windows 11 is built with the file list from [UUP dump](https://uupdump.net/) and files are downloaded directly from Microsoft's Windows Update servers. The UUP dump script generates a Windows ISO which we then inject [virtio drivers](https://docs.fedoraproject.org/en-US/quick-docs/creating-windows-virtual-machines-using-virtio-drivers/index.html) into along with an `autounattend.xml` script and a variety of Powershell scripts to automate the installation. To keep the VM small and fast we remove a lot of the default Windows components and services including Windows Defender, Windows Update, most default apps, and also disable things like paging, sleep and hibernation, plus the hard drive is compressed and trimmed to be <10GB. This image and VM state is then snapshotted and saved to a cache directory so that subsequent runs can use the cached VM state to startup quickly.

Communication between the VM and the host is done via the QEMU Agent and a QEMU-started Samba server (available on the host in `/tmp/qemu-status` or in the container in `\\10.0.2.4\qemu`). During installation and execution, multiple debugging services are started (you'll need to forward these ports using Docker):
- a QEMU-run VNC server is available on port `5950` (not compatible with Apple Screen Sharing),
- the QEMU Monitor is available on port `55556` (supported commands are [here](https://qemu-project.gitlab.io/qemu/system/monitor.html)), and
- the QEMU Agent is available on port `44444` (protocol is [here](https://qemu.readthedocs.io/en/latest/interop/qemu-ga-ref.html)).
