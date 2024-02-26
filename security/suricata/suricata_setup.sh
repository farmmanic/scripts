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
    sudo apt install -y suricata jq
}

if ! command -v suricata &>/dev/null; then
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

##add source list
sources="./sources.txt"
while read line; do
	sudo suricata-update enable-source "$line"
done < "$sources"

sudo suricata-update
sudo systemctl restart suricata
