#!/bin/bash

# TODO CEMU
VERSION="1.3"

echo 'This script sets up some quality of life things for the GPD Win:'
echo '  - Installs updates'
echo '  - Installs useful packages (ssh, tmux, vim, emulators, etc...)'
echo '  - Fixes rotation on login screen'
echo '  - Enables Wayland (fixes screen tearing on desktop)'
echo '  - Sets up ssh keys'
echo '  - Sets up passwordless login to other devices (e.g. cloud storage)'
#echo '  - Sets up shared directory for large game files'
echo

if [[ $EUID == 0 ]]; then
	echo 'Error: Do not run this script as root!'
	echo 'Commands that need root use sudo instead!'
	exit 1
fi

echo 'Before running this script, go into your display settings and change the'
echo 'built-in screen rotation to "right".'
echo
echo 'Some commands require sudo. You will be asked for your sudo password.'
echo

read -p 'Continue? [y/n]: ' yn
if [[ ! $yn =~ [Yy] ]]; then
	exit
fi
echo

# Set the hostname
read -p 'Customize the hostname (leave blank to not change): ' newhostname
if [[ $newhostname != '' ]]; then
	sudo hostnamectl set-hostname $newhostname
fi
echo

# Remove some crap we don't care about
echo 'Removing some unwanted pre-bundled packages'
sudo apt remove --purge libreoffice*
sudo apt clean
sudo apt autoremove

# Install updates and useful packages
echo 'Installing updates and useful packages'
sudo apt update
sudo apt upgrade
sudo apt install \
	barrier \
	discord \
	fceux \
	filezilla \
	flatpak \
	htop \
	jstest-gtk \
	lutris \
	openssh-server \
	snapd \
	steam \
	tmux \
	vim \
	vlc
echo

# Fix rotation on login screen.
# Assumes you've changed rotation for your user already.
# https://askubuntu.com/questions/1003964/how-to-rotate-login-screen-in-gdm3/1003965#1003965
echo 'Fixing rotation on login screen'
LOCALMONFILE=~/.config/monitors.xml
GLOBALMONFILE=/var/lib/gdm3/.config/monitors.xml
echo "Copying $LOCALMONFILE to $GLOBALMONFILE"
sudo cp $LOCALMONFILE $GLOBALMONFILE
echo

# Enable Wayland in addition to XOrg
echo 'Enabling Wayland. Wayland fixes screen tearing on the desktop.'
echo 'This option does not force Wayland on, it just adds an option to use'
echo 'Wayland on the login screen. You can still use XOrg if you want.'
sudo sed -i 's/WaylandEnable=false/WaylandEnable=true/' /etc/gdm3/custom.conf
echo

# NOTE this was disabled because I no longer share this device.
# Set up shared directory for large game files
#echo 'Setting up shared directory for large game files'
#SHAREDIR=/home/shared
#SHAREGRP=shared
#echo "Creating group '$SHAREGRP'"
#sudo groupadd $SHAREGRP
#echo "Adding user '$USER' to group '$SHAREGRP'"
#sudo usermod --append --groups $SHAREGRP $USER
#echo "Creating $SHAREDIR"
#sudo mkdir $SHAREDIR
#echo "Making $SHAREDIR accessible by group '$SHAREGRP'"
#sudo chgrp -R $SHAREGRP $SHAREDIR
#sudo chmod -R 2755 $SHAREDIR
#echo "Creating shared ROM directories"
#SHAREDIRROMS=$SHAREDIR/roms
#ROMDIRS=(
#	'GBA'
#	'GBC'
#	'N64'
#	'NES'
#	'PS1'
#	'PS2'
#	'PSP'
#	'SNES'
#)
#for i in ${!ROMDIRS[@]}; do
#	dirname=$SHAREDIRROMS/${ROMDIRS[$i]}
#	echo "Making $dirname"
#	mkdir -p $dirname
#done
#echo

# Instead we'll just use a basic games directory
echo "Creating Games directory in user's home"
mkdir ~/Games
echo

echo 'Generating SSH key'
echo 'This key is used to access other devices over the network.'
echo 'The GPD Win is a portable (i.e. stealable) device, so put a password on this key!'
echo 'The Pop_OS Keyring can be configured to unlock this key on login.'
ssh-keygen
echo

# Set up passwordless login with remote machines.
echo 'Here you can copy your ssh key to a remote machine, for passwordless login.'
echo 'This will prompt for the user and hostname. Examples:'
echo '    user@some.domain.com'
echo '    user@some.domain.com -p 1234'
keepgoing() {
	read -p 'Copy ssh key to a remote server? [y/n]: ' yn
	[[ $yn =~ [Yy] ]]
}
while keepgoing; do
	read -p 'Enter [user@]hostname [-p port]: ' hoststr
	ssh-copy-id $hoststr
done
echo

echo 'Installing flatpak apps'
FLATPAKAPPS=(
	'com.moonlight_stream.Moonlight'
	'com.snes9x.Snes9x'
	'io.mgba.mGBA'
	'net.kuribo64.melonDS'
	'net.pcsx2.PCSX2'
	'net.rpcs3.RPCS3'
	'org.citra_emu.citra'
	'org.DolphinEmu.dolphin-emu'
	'org.duckstation.DuckStation'
	'org.ppsspp.PPSSPP'
)
for i in ${!FLATPAKAPPS[@]}; do
	app=${FLATPAKAPPS[$i]}
	echo "Installing $app"
	flatpak install $app
done
echo

echo 'Momentarily running flatpak apps to create config directories'
echo 'Running fceux'
timeout 1 fceux &> /dev/null
for i in ${!FLATPAKAPPS[@]}; do
	app=${FLATPAKAPPS[$i]}
	echo "Running $app"
	timeout 1 flatpak run $app &> /dev/null
done
echo

# Free File Sync doesn't have a deb, and flatpak can't sync .var, so we're stuck doing this.
# This extracts the relative download URL from the HTML, then constructs our own
# version-independent download link. Yeah, this is gross.
echo 'Installing FreeFileSync'
FFS_ROOT='https://freefilesync.org'
FFS_FILENAME=$(curl --silent $FFS_ROOT/download.php | grep -Po "FreeFileSync.*Linux.tar.gz")
FFS_DL=$FFS_ROOT/download/$FFS_FILENAME
echo "Found at $FFS_DL"
wget $FFS_DL
tar xf $FFS_FILENAME
FFS_INST=$(echo $FFS_FILENAME | grep -Po "FreeFileSync_.*_")Install.run
./$FFS_INST
rm FreeFileSync*
rm ~/Desktop/*.desktop
echo 'Cleaning up FreeFileSync install files'
echo

echo 'Finished setting up the device, finally!'
echo 'You should probably restart so everything takes effect properly.'
echo
echo 'If you want to remove the onscreen keyboard, install this extension.'
echo https://extensions.gnome.org/extension/3222/block-caribou-36/
echo "The correct version is: $(gnome-shell --version)"

