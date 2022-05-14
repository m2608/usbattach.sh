Script to attach (detach) usb devices to (from) virtual machines. Uses
`qm monitor` as backend. Tested only in Proxmox environment.

Requirements: `fzf`, `expect`.

Usage:

    usbattach.sh [VM id]

Script does not perform any checks (eg. whether or not device already
attached), only runs `qm monitor` commands.

It uses `fzf` to show interface and `expect` to interact with `qm monitor`.

Being started without parameters it shows a list of running VMs.

Being started with VM id as first parameter, it shows a list of attached
devices for this specific VM.

https://user-images.githubusercontent.com/20361405/168440240-0a41e248-242d-4155-9fa2-1fdafbfc2684.mp4
