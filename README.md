Script to attach (detach) usb devices to (from) virtual machines. Uses
`qm monitor` as backend. Tested only in Proxmox environment.

Requirements: [fzf](https://github.com/junegunn/fzf), [expect](https://core.tcl-lang.org/expect/index).

Usage:

    usbattach.sh [VM id]

Script does not perform any checks (eg. whether or not device already
attached), only runs `qm monitor` commands.

It uses `fzf` to show interface and `expect` to interact with `qm monitor`.

Being started without parameters it shows a list of running VMs.

Being started with VM id as first parameter, it shows a list of attached
devices for this specific VM.

https://user-images.githubusercontent.com/20361405/168440463-6e85438f-6614-4593-aca9-5d8237e24a94.mp4
