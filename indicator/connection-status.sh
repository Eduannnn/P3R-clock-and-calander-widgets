#!/bin/sh
# Read cached network state; do not scan or alter connections.
export LC_ALL=C
nmcli --terse --fields IN-USE,SIGNAL device wifi list --rescan no 2>/dev/null |
    while IFS=: read -r active signal; do
        [ "$active" = '*' ] && printf 'wifi:%s\n' "$signal"
    done

nmcli --terse --fields DEVICE,TYPE,STATE device status 2>/dev/null |
    while IFS=: read -r interface type state; do
        [ "$type" = ethernet ] || continue
        case "$state" in connected|'connected (externally)') ;; *) continue ;; esac
        # An active tether must provide a default route, not just USB presence.
        routes=$(ip -4 route show default dev "$interface" 2>/dev/null)
        routes6=$(ip -6 route show default dev "$interface" 2>/dev/null)
        [ -n "$routes$routes6" ] || continue
        device=$(readlink -f "/sys/class/net/$interface/device")
        driver=$(readlink -f "$device/driver")
        [ "${driver##*/}" = ipheth ] || continue
        while [ -n "$device" ] && [ "$device" != / ]; do
            if [ -r "$device/idVendor" ] && [ -r "$device/product" ]; then
                vendor=$(cat "$device/idVendor")
                product=$(cat "$device/product")
                if [ "$vendor" = 05ac ] && [ "$product" = iPhone ]; then
                    printf 'iphone:true\n'
                fi
                break
            fi
            device=${device%/*}
        done
    done
