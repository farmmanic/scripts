##setup and install suricata
#requirements for install should add to requirments.txt

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run with sudo."
    exit 1
fi
apt update -y && apt upgrade -y

#OISF ppa

suricata_install() {
    sudo add-apt-repository ppa:oisf/suricata-stable -y
    sudo apt update
    sudo apt install -y suricata jq
}

install_dependencies() {
    # Check if requirements.txt exists
    if [ -f "requirements.txt" ]; then
        while IFS= read -r package; do
            apt install -y "$package"
        done < "requirements.txt"
    fi
}
#install suricata and dependacies
if ! command -v suricata &>/dev/null; then
    install_dependencies
    suricata_install
fi

#make sure suricata is enabled
if ! /lib/systemd/systemd-sysv-install is-enabled suricata &>/dev/null; then
	systemctl enable suricata
fi

change_config()
{
##get ip addresses and put them into a comma seperated list with cidr extentions
ipaddress=$(ip addr show | grep -E 'inet.*brd' | awk '{print $2}' | cut -d/ -f1 | tr '\n' ' ' | sed 's# \([^ ]\)#\/24,\1#g'
)
sudo sed -i "s#^[[:space:]]HOME_NET:.*#  HOME_NET: \"[$ipaddress]\"#g" /etc/suricata/suricata.yaml

##change interface to match system default internet interface
internet_interface=$(ip route | awk '/default/ {print $5}')
sudo sed -i "s/^[[:space:]]*- interface:.*/- interface: $internet_interface/g" /etc/suricata/suricata.yam
}
change_config


# Check if sources.txt exists
if [ -f "sources.txt" ]; then
    sources="./sources.txt"
    # Loop through each line in sources.txt and enable sources
    while IFS= read -r line; do
        if sudo suricata-update enable-source "$line"; then
            echo "Enabled Suricata source: $line"
        else
            echo "Failed to enable Suricata source: $line"
        fi
    done < "$sources"
else
    echo "Error: sources.txt not found."
fi
# Define the cron schedule
cron_schedule="0 0 * * 0 sudo suricata-update"

# Check if the cron job already exists in the crontab
if ! sudo crontab -l | grep -q "$cron_schedule"; then
    # Add the cron job if it doesn't exist
    echo "$cron_schedule" | sudo crontab -
fi

sudo suricata-update
sudo systemctl restart suricata
