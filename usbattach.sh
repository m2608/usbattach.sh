#!/bin/sh

# Script to attach and detach usb devices to virtual machines. Uses
# `qm monitor` as backend. Tested only in Proxmox environment.
#
# Requirements: fzf, expect.
#
# Usage: usbattach.sh [VM id]
#
# Script does not perform any checks (eg. whether or not device already
# attached), only runs `qm monitor` commands.
#
# It uses `fzf` to show interface and `expect` to interact with `qm monitor`.
#
# Being started without parameters it shows a list of running VMs.
#
# Being started with VM id as first parameter, it shows a list of attached
# devices for this specific VM.

# Runs QEMU Monitor command. 
#
# Params:
#     $1 - VM id
#     $2 - command
#
# Returns command output.
#
# Example:
#     run_command 100 "info usbhost"
#
run_command()
{
    vmid=$1
    cmd=$2

    # We are using expect to run command and fetch it's output.
    # TERM unset to disable ANSI output.
    output=`TERM= expect <<EOD
log_user 0
spawn qm monitor $vmid
expect "qm> "
send "$cmd\n"
expect -re "(.*)qm> "
puts \\$expect_out(1,string)
send "quit\n"
EOD
`

    # Remove CR character, remove first line (it is the command itself).
    echo "$output" \
        | tr -d '\r' \
        | sed '1d'
}

# Get formatted list of running VMs.
# 
# Example:
#     get_running_vm_list
#
get_running_vm_list()
{
    # Get VM list.
    vmlist=`qm list | sed -n '1p;2,${/running/{p}}'`

    # Get string with minimal number of space at the beginning.
    padding=`echo "$vmlist" | sed -r 's/^(\s*).*/\1/' | sort | sed '2,${d}'`

    # Remove spaces at the beginning of every line.
    echo "$vmlist" | sed -r "s/^\s{${#padding}}//"
}

# Gets info about USB devices on host.
#
# Params:
#     $1 - VM id
#
# Returns pretty formatted device list.
#
# Example:
#     info_host 100
#
info_host()
{
    vmid=$1

    # Print header.
    printf "%3s %7s %11s %12s    %s\n" "Bus" "Port" "Speed" "VID&PID" "Device"

    # Run command to get info about host usb devices.
    # sed is used here to combine lines in pairs.
    run_command $vmid "info usbhost" \
        | sed -r -n 'N;s/\n/ /;p' \
        | while read line; do

            # Parse bus, port, device speed, vid, pid and device string from every line.
            bus=`echo $line | sed -r 's/^\s*Bus ([0-9]+),.*/\1/'`
            port=`echo $line | sed -r 's/^.*, Port ([0-9]+(\.[0-9]+)?),.*/\1/'`
            speed=`echo $line | sed -r 's/^.*, Speed ([0-9]+(\.[0-9]+)? [^ ]+)\s.*/\1/'`
            vidpid=`echo $line | sed -r 's/^.*USB device ([0-9a-f]{4}):([0-9a-f]{4}),.*/\1:\2/'`
            device=`echo $line | sed -r 's/^.*USB device ([0-9a-f]{4}):([0-9a-f]{4}),\s+(.*)/\3/'`

            printf "%3d %7s %11s %12s    %s\n" $bus $port "$speed" $vidpid "$device"
        done
}

# Gets info about USB devices on guest.
#
# Params:
#     $1 - VM id
#
# Returns pretty formatted attached device list.
#
# Example:
#     info_guest 100
#
info_guest()
{
    vmid=$1

    # Print header.
    printf "%-8s %11s    %s\n" "ID" "Speed" "Device"

    run_command $vmid "info usb" \
        | while read line; do
            # Parse device speed, device string and id.
            speed=`echo $line | sed -r 's/^.*, Speed ([0-9]+(\.[0-9]+)? [^ ]+),\s.*/\1/'`
            device=`echo $line | sed -r 's/^.*Product (.*)(,\s+ID:.*)?/\1/'`
            # If there is no ID, let it be empty.
            id=`echo $line | sed -r "s/^.*,\s+ID:\s*(.*)/\1/; t; s/.*//"`

            printf "%-8s %11s    %s\n" "$id" "$speed" "$device"
        done
}

# Attaches device to VM.
#
# Params:
#     $1 - VM id
#     $2 - USB bus number
#     $3 - USB port number
#
# Returns nothing.
#
# Example:
#     attach_device 100 2 3.3
#
attach_device()
{
    vmid=$1
    bus=$2
    port=$3

    if test -n "$bus" -a -n "$port"; then
        run_command $vmid "device_add usb-host,hostbus=$bus,hostport=$port,id=usb${bus}_${port}"
    fi
}

# Detaches device from VM.
# 
# Params: 
#     $1 - VM id
#     $2 - USB device id
#
# Returns nothing.
#
# Example:
#     detach_device 100 usb2_3.3
#
detach_device()
{
    vmid=$1
    id=$2

    if test -n "$id"; then
        run_command $vmid "device_del $id"
    fi
}

# Check if fzf installed.
if ! which fzf > /dev/null ; then 
    echo "fzf not installed"
    exit 1
fi

# Check if expect installed.
if ! which expect > /dev/null ; then 
    echo "expect not installed"
    exit 1
fi

# Show usage.
if test "$1" = "--help" -o "$1" = "-h"; then
    echo Usage: `basename "$0"` "[VM id]"
    exit 0
fi

# Execute subroutine.
if test "$1" = "--sub" -a -n "$2"; then
    subroutine="$2"
    shift
    shift
    $subroutine $@
    exit 0
fi

vmid=$1

# If there is a VM id in args, check whether or not this VM is running.
if test -n "$vmid"; then
    # Exclamation mark is used to invert grep exit status.
    if ! qm list | sed '1d' | grep -qE "^\s*$vmid\s+\w+\s+running" ; then
        echo "No VM with id \"$vmid\" is running."
        # Clear variable if VM is not running.
        vmid=""
    fi
fi

# Default dialog: "Detach device".
variant="detach"

# Keybindings descriptions for different dialogs.

list_help="
Enter  Choose VM
Ctrl+R Refresh list
Esc    Exit

"

attach_help="
TAB    Switch to detach dialog
Enter  Attach device
Ctrl+R Refresh list
Esc    Show VM list

"

detach_help="
TAB    Switch to attach dialog
Enter  Detach device
Ctrl+R Refresh list
Esc    Show VM list

"

# Main dialog loop.
while true; do
    # If vmid variable is cleared, show "choose vm" dialog.
    if test -z "$vmid"; then
        fzf_out=`"$0" --sub get_running_vm_list \
            | fzf --ansi --no-info \
            --layout=reverse \
            --header "$list_help" \
            --header-lines 1 \
            --bind "ctrl-r:reload(\"$0\" --sub get_running_vm_list)" \
            --prompt "Choose VM: "`

        # Exit if not data returned from fzf.
        if test -z "$fzf_out"; then
            break
        fi

        # Get chosen VM id.
        vmid=`echo "$fzf_out" | sed -r 's/^\s*([0-9]+)\s.*/\1/'`
        vmname=`echo "$fzf_out" | sed -r 's/^\s*([0-9]+)\s+(.*[^ ])\s+running.*/\2/'`
    fi

    # Loop until Esc pressed.
    while true; do

        # We can switch between "attach" and "detach" screens with TAB.
        case $variant in
            attach)
                # Show "Attach device" dialog.
                fzf_out=`info_host $vmid \
                    | fzf --ansi --no-info \
                    --layout=reverse \
                    --header "$attach_help" \
                    --header-lines 1 \
                    --prompt "Attach to VM $vmid ($vmname): " \
                    --bind "ctrl-r:reload(\"$0\" --sub info_host $vmid)" \
                    --expect=tab`
                ;;
            detach)
                # Show "Detach device" dialog.
                fzf_out=`info_guest $vmid \
                    | fzf --ansi --no-info \
                    --layout=reverse \
                    --header "$detach_help" \
                    --header-lines 1 \
                    --prompt "Detach from VM $vmid ($vmname): " \
                    --bind "ctrl-r:reload(\"$0\" --sub info_guest $vmid)" \
                    --expect=tab`
                ;;
        esac

        # Get pressed key and selected line data.
        key=`echo "$fzf_out" | sed -n '1p'`
        data=`echo "$fzf_out" | sed -n '2p'`

        if test -z "$key"; then
            if test -z "$data"; then
                # Return to "choose vm" dialog if not data returned (eg. Esc pressed).
                vmid=""
                break
            fi
            # Parse data from output and attach or detach device.
            case $variant in
                attach)
                    bus=`echo "$data" | sed -r 's/^Bus:\s*([0-9]+)\s.*/\1/'`
                    port=`echo "$data" | sed -r 's/^.*Port:\s*([0-9]+(\.[0-9]+)?)\s.*/\1/'`
                    attach_device $vmid $bus $port
                    ;;
                detach)
                    # There could be no ID, leave the variable empty in that case.
                    id=`echo "$data" | sed -r 's/^.*ID:\s*(.*)/\1/; t; s/.*//'`
                    detach_device $vmid $id
                    ;;
            esac
        elif test "$key" = "tab"; then
            # Switch between "attach" and "detach" dialogs.
            case $variant in
                attach)
                    variant="detach"
                    ;;
                detach)
                    variant="attach"
                    ;;
            esac
        fi
    done
done

