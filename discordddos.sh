#!/bin/bash

echo -e "Discord DDoS Detection script coded by Dicky\n"

# Network interface and dump directory
interface="eth0"
dumpdir="/root/dumps"

# Webhook URL securely stored in environment variable
webhook_url="${WEBHOOK_URL:-'https://your-webhook-url'}"

# Function to calculate network statistics
calculate_stats() {
    local interface=$1
    local old_stats new_stats

    # Read current stats
    old_stats=$(grep "$interface:" /proc/net/dev | awk -F'[: ]+' '{print $2, $3}')
    sleep 1
    new_stats=$(grep "$interface:" /proc/net/dev | awk -F'[: ]+' '{print $2, $3}')

    # Calculate packet per second (pps) and bytes
    local old_bytes=$(echo "$old_stats" | awk '{print $1}')
    local old_packets=$(echo "$old_stats" | awk '{print $2}')
    local new_bytes=$(echo "$new_stats" | awk '{print $1}')
    local new_packets=$(echo "$new_stats" | awk '{print $2}')

    local pps=$((new_packets - old_packets))
    local bytes=$((new_bytes - old_bytes))

    # Calculate bandwidth in different units
    local kbps=$((bytes / 1024))
    local mbps=$((bytes / 1024**2))
    local gbps=$((bytes / 1024**3))

    echo "$pps $kbps $mbps $gbps"
}

# Function to send alert to Discord
send_discord_alert() {
    local status=$1
    local pps=$2
    local mbps=$3
    local color=$4
    local description=$5
    local thumbnail_url=$6

    curl -H "Content-Type: application/json" -X POST -d "{
      \"embeds\": [{
        \"title\": \"${status} Attack\",
        \"username\": \"Attack Alerts\",
        \"color\": ${color},
        \"thumbnail\": {\"url\": \"${thumbnail_url}\"},
        \"footer\": {
          \"text\": \"System message regarding attack activity.\",
          \"icon_url\": \"https://cdn.countryflags.com/thumbs/united-states-of-america/flag-800.png\"
        },
        \"description\": \"${description}\",
        \"fields\": [
          {\"name\": \"**Server Provider**\", \"value\": \"OVH LLC\", \"inline\": false},
          {\"name\": \"**IP Address**\", \"value\": \"$(hostname -I)\", \"inline\": false},
          {\"name\": \"**Packets**\", \"value\": \"${pps} Pps\", \"inline\": false},
          {\"name\": \"**Bandwidth**\", \"value\": \"${mbps} Mbps\", \"inline\": false}
        ]
      }]
    }" "$webhook_url"
}

# Main monitoring loop
while true; do
    read -r pps kbps mbps gbps < <(calculate_stats "$interface")

    # Display real-time packet info
    echo -ne "\r$pps packets/s"

    # Detect if an attack is occurring based on high PPS threshold
    if [ "$pps" -gt 10000 ]; then
        echo "Attack Detected. Monitoring Incoming Traffic."
        tcpdump -n -s0 -c 1500 -w "$dumpdir/capture.$(date +'%Y%m%d-%H%M%S').pcap"

        # Send attack alert
        send_discord_alert "Detected" "$pps" "$mbps" 15158332 "Detection of an attack" "https://imgur.com/a/cZAa3Pu"

        # Wait for mitigation and stop tcpdump
        echo "Paused for mitigation."
        sleep 120 && pkill -HUP -f /usr/sbin/tcpdump

        # Send attack stopped alert
        send_discord_alert "Stopped" "$pps" "$mbps" 3066993 "End of attack" "https://imgur.com/a/1YNwLCo.gif"
    fi
done
