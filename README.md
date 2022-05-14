Script to attach and detach usb devices to virtual machines. Uses
QEMU monitor as backend.

I mainly use it to attach and detach devices in Proxmox environment.

Requirements: `fzf`, `expect`.

Usage:

    usbattach.sh [VM id]

Script does not perform any checks (eg. whether or not device already
attached), only runs `qm monitor` commands.

It uses `fzf` to show interface and `expect` to interact with `qm monitor`.

Being started without parameters it shows a list of running VMs.

Being started with VM id as first parameter, it shows a list of attached
devices for this specific VM.

![](screencast/usbattach.mp4)
