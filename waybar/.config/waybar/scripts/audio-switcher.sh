#!/bin/bash

get_sink_icon() {
    local sink="$1"
    local info bus form

    info=$(pactl list sinks | awk -v s="$sink" '
        /Name:/ { found = ($2 == s) }
        found && /device\.bus =/ { gsub(/"/, "", $3); print "bus=" $3 }
        found && /device\.form_factor =/ { gsub(/"/, "", $3); print "form=" $3 }
    ')

    bus=$(echo "$info" | grep "^bus=" | cut -d= -f2)
    form=$(echo "$info" | grep "^form=" | cut -d= -f2)

    if [ "$bus" = "bluetooth" ]; then
        echo "󰂯"
    elif [ "$form" = "headphone" ]; then
        echo "󰋋"
    elif [ "$form" = "headset" ]; then
        echo "󰋎"
    elif [ "$bus" = "usb" ]; then
        echo ""
    elif [ "$form" = "internal" ] || [ "$bus" = "pci" ]; then
        echo "󰓃"
    else
        echo "󰕾"
    fi
}

case "$1" in
    status)
        current=$(pactl get-default-sink)
        sink_icon=$(get_sink_icon "$current")
        desc=$(pactl list sinks | awk -v sink="$current" '
            /Name:/ { found = ($2 == sink) }
            /Description:/ { if (found) { print substr($0, index($0,$2)); exit } }
        ')
        muted=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | grep -c MUTED)
        vol=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ | awk '{printf "%d", $2 * 100}')

        if [ "$muted" -gt 0 ]; then
            vol_icon="󰝟"
        elif [ "$vol" -le 0 ]; then
            vol_icon="󰕿"
        elif [ "$vol" -le 50 ]; then
            vol_icon="󰖀"
        else
            vol_icon="󰕾"
        fi

        echo "{\"text\": \"$sink_icon\", \"alt\": \"$vol_icon\", \"tooltip\": \"$desc\"}"
        ;;

    vol-up)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
        pkill -RTMIN+8 waybar
        ;;

    vol-down)
        wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
        pkill -RTMIN+8 waybar
        ;;

    pick)
        current=$(pactl get-default-sink)

        sink_list=$(pactl list sinks | awk '
            /Name:/ { name = $2 }
            /Description:/ { print substr($0, index($0,$2)) "||" name }
        ')

        sink_count=$(echo "$sink_list" | wc -l)

        if [ "$sink_count" -eq 1 ]; then
            sink=$(echo "$sink_list" | awk -F'\\|\\|' '{print $2}' | xargs)
        else
            chosen=$(echo "$sink_list" | while IFS= read -r line; do
                name=$(echo "$line" | awk -F'\\|\\|' '{print $2}' | xargs)
                desc=$(echo "$line" | awk -F'\\|\\|' '{print $1}')
                type_icon=$(get_sink_icon "$name")
                if [ "$name" = "$current" ]; then
                    echo "✔ $type_icon  $desc||$name"
                else
                    echo "  $type_icon  $desc||$name"
                fi
            done | rofi -dmenu -p "Output" -i -lines 5)

            [ -z "$chosen" ] && exit 0

            sink=$(echo "$chosen" | awk -F'\\|\\|' '{print $2}' | xargs)
            [ -z "$sink" ] && exit 0
        fi

        pactl set-default-sink "$sink"
        pactl list short sink-inputs | awk '{print $1}' | \
            xargs -I{} pactl move-sink-input {} "$sink"
        pkill -RTMIN+8 waybar
        ;;

esac
