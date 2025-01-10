#!/bin/bash
# Version 1.0
# Sets up a seedbox using Deluge and NordVPN

# Install updates
apt update
apt upgrade

# Install packages
apt install\
	beep\
	curl\
	deluge\
	deluged\
	deluge-console\
	figlet\
	fzf\
	netstat\
	software-properties-common\
	tmux\
	xpra

# Immediately disable the service from auto-running.
# We want to manually verify the VPN is running before starting Deluge.
systemctl stop deluged.service

# Manually apply this patch to Deluge to work around Python's
# infuriatingly frequent breaking changes to their own built-in libraries.
# This fixes the log spam.
# https://git.deluge-torrent.org/deluge/commit/?h=develop&id=351664ec071daa04161577c6a1c949ed0f2c3206
sed --in-place 's/findCaller(self, stack_info=False):/findCaller(self, *args, **kwargs):/' /usr/lib/python3/dist-packages/deluge/log.py

# Get some config
wget -O ~/.vimrc https://gist.githubusercontent.com/Mimickal/38c7dc7851410238bbddff305322b54b/raw/f0091e25ccd8ee01306e52a151f488af9f6c94c6/.vimrc%2520without%2520plugs
wget -O ~/.tmux.conf https://gist.githubusercontent.com/Mimickal/b5c719432170b8dd25a3235a568d6b44/raw/fd255c2e682457a763d18f67ee1abeade44f8efc/.tmux.conf%25203.1b

# Enable system beep (Screw you Ubuntu, we want to know when it's up and running, right?)
sed -i -r 's/blacklist pcspkr/#blacklist pcspkr/' /etc/modprobe.d/blacklist.conf

# Enable proper X11 forwarding
sed -i -r 's/#?X11Forwarding.*/X11Forwarding yes/' /etc/ssh/sshd_config
sed -i -r 's/#?X11UseLocalhost.*/X11UseLocalhost no/' /etc/ssh/sshd_config

# Get some helpful scripts
IP_INFO_SCRIPT='/usr/local/bin/print-ip-info'
DELUGE_STATUS_SCRIPT='/usr/local/bin/deluge-status'
PROFILE_SCRIPT='/etc/profile.d/startup-info.sh'

curl "https://raw.githubusercontent.com/Mimickal/FunboxScripts/master/print-ip-info.py" \
	--output $IP_INFO_SCRIPT
curl "https://raw.githubusercontent.com/Mimickal/FunboxScripts/master/deluge-status.pl" \
	--output $DELUGE_STATUS_SCRIPT
curl "https://raw.githubusercontent.com/Mimickal/FunboxScripts/master/login-info.sh" \
	--output $PROFILE_SCRIPT

chmod +x $IP_INFO_SCRIPT
chmod +x $DELUGE_STATUS_SCRIPT

# Nordvpn setup
wget https://repo.nordvpn.com/deb/nordvpn/debian/pool/main/nordvpn-release_1.0.0_all.deb
dpkg -i nordvpn-release_1.0.0_all.deb
sh <(curl -sSf https://downloads.nordcdn.com/apps/linux/install.sh)

usermod -aG nordvpn $USER
nordvpn set analytics off
nordvpn set autoconnect on
nordvpn set killswitch on
nordvpn whitelist add subnet 192.168.1.0/24

echo "Open this in your local browser and do the login."
echo "Copy the link your browser wants NordVPN to open."
echo "Come back here and run 'nordvpn login --callback <link>' (use quotes)."

