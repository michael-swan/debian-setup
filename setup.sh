#!/bin/bash

# Setup environment
die() { echo FAILURE: "$@" 1>&2; exit 1; }
valid_reg() {
	local access uid gid
	read -r access uid gid < <(stat -c '%a %u %g' "$1")
	[[ "$access" -eq 644 && "$uid" -eq 0 && "$gid" -eq 0]] || die "Invalid permission mode, owner, or group for regular file '$1'"
}
valid_exe() {
	local access uid gid
	read -r access uid gid < <(stat -c '%a %u %g' "$1")
	[[ "$access" -eq 755 && "$uid" -eq 0 && "$gid" -eq 0]] || die "Invalid permission mode, owner, or group for executable file '$1'"
}
valid_dir() {
	local access uid gid
	read -r access uid gid < <(stat -c '%a %u %g' "$1")
	[[ "$access" -eq 755 && "$uid" -eq 0 && "$gid" -eq 0]] || die "Invalid permission mode, owner, or group for directory '$1'"
}
find_exe() {
	find "$@" -type f -executable
}
find_reg() {
	find "$@" -type f -not -executable
}
find_dir() {
	find "$@" -type d
}
valid_tree() {
	find_exe "$@" | while read file; do
		valid_exe "$file"
	done
	find_reg "$@" | while read file; do
		valid_reg "$file"
	done
	find_dir "$@" | while read dir; do
		valid_dir "$dir"
	done
}
no_exe_tree() {
	find_exe /usr/share/fonts/X11/gohu/ /usr/share/fonts/truetype/tahoma/ | while read file; do
		die 'Verify no executable files in gohu/ or tahoma/'
	done
}
# NOTE: A "valid" file/directory in this case simply refers to those with the most common default permission settings.

[ `id -u` -eq 0 ] || die 'Must be run as root'
umask 0022 || die 'Must set permission mask to 0022'

cd `dirname "$0"` \
	|| die "Enter script's directory"

# 0. Fix apt
cp misc/sources.list /etc/apt/sources.list \
	|| die 'Select repositories'
install -o root -g root -m 644 misc/10no-check-valid-until /etc/apt/apt.conf.d/10no-check-valid-until \
	|| die 'Fix repository "valid until" behaviour'
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 94558F59 \
	|| die 'Authorize Spotify repositories'
dpkg --add-architecture i386 \
	|| die 'Add i386 architecture'
apt update \
	|| die 'Package database update'
apt dist-upgrade \
	|| die 'Package upgrade'

# 1. Install base packages
apt install `cat pkgs.txt` \
	|| die 'Install base packages'

# 2. Configure default user
user=`id -nu 1000` \
	|| die "Find default user's username"
adduser "$user" sudo \
	|| die 'Add default user to sudo group'

# 3. Fix fonts
apt remove fonts-dejavu-core ttf-bitstream-vera fonts-droid \
	|| die 'Uninstall awful fonts'
rm /etc/fonts/conf.d/{10-scale-bitmap-fonts.conf,70-no-bitmaps.conf}
sed -i 's/Bitstream Vera/Liberation/; s/Liberation Sans Mono/Liberation Mono/' /etc/fonts/conf.d/*-latin.conf \
	|| die 'Configure latin fonts'
grep 'Bitstream Vera' /etc/fonts/conf.d/*-latin.conf \
	&& die 'Verify configuration of latin fonts'
install -o root -g root -m 644 misc/local.conf /etc/fonts/local.conf \
	|| die 'Fix font aliasing and hinting'

# 4. Install Gohu and Tahoma fonts
cp -rp gohu/ /usr/share/fonts/X11/ \
	|| die 'Copy gohu/'
cp -rp tahoma/ /usr/share/fonts/truetype/ \
	|| die 'Copy tahoma/'
install -o root -g root -m 644 misc/20-fonts.conf /usr/share/X11/xorg.conf.d/20-fonts.conf \
	|| die 'Add gohu/ to Xorg FontPath'
valid_tree /usr/share/fonts/X11/gohu/ /usr/share/fonts/truetype/tahoma/
no_exe_tree /usr/share/fonts/X11/gohu/ /usr/share/fonts/truetype/tahoma/

# 5. Install Windows 2000 Theme
cp -rp win2k/ /usr/share/themes/ \
	|| die 'Copy win2k/'
valid_tree /usr/share/themes/win2k/
no_exe_tree /usr/share/themes/win2k/

# 6. Configure XTerm
rm /etc/X11/Xresources/x11-common
install -o root -g root -m 644 misc/x11-common /etc/X11/Xresources/x11-common \
	|| die 'Configure XTerm'

# 7. Fix key repeat
sed -i '/\/usr\/bin\/X/ s/$/ -ardelay 200 -arinterval 25/' /etc/X11/xinit/xserverrc \
	|| die 'Fix key repeat'

# 8. Configure OpenBox
cp -rp openbox/ /etc/xdg/ \
	|| die 'Copy openbox/'
valid_tree /etc/xdg/openbox/
autostart_is_exe=0
find_exe /etc/xdg/openbox/ | while read file; do
	[ "$file" == /etc/xdg/openbox/autostart ] && autostart_is_exe=1
	[ "$file" != /etc/xdg/openbox/autostart ] && die 'Verify a minimal set of executables in openbox/'
done
[ "$autostart_is_exe" -eq 1 ] || die 'Verify openbox/autostart is executable'
unset autostart_is_exe

# 9. Configure Tint2
install -o root -g root -m 644 misc/tint2rc /etc/xdg/tint2/tint2rc \
	|| die 'Configure Tint2'

# 10. Update font cache
fc-cache -f -v \
	|| die 'Update font cache'

# 11. Eliminate password failure delays (given physical access)
sed -i '/pam_unix.so/ s/$/ nodelay/' /etc/pam.d/common-auth \
	|| die 'Eliminate password failure delays'
grep 'nodelay' /etc/pam.d/common-auth && die 'Verify password failure delays have been eliminated'

# 12. Change default editor to vim
install -o root -g root -m 644 misc/editor.sh /etc/profile.d/editor.sh \
	|| die 'Change default editor to vim'

# 13. Set git configuration
echo 'Git Configuration'

echo -n 'Full Name:'; read git_name \
	|| die 'Read git full name'
echo -n 'Email:';     read git_email \
	|| die 'Read git email'

sudo -u "$user" git config --global user.name "$git_name" \
	|| die 'Set git full name'
sudo -u "$user" git config --global user.email "$git_email" \
	|| die 'Set git email'

# 14. Generate a new SSH key
sudo -u "$user" ssh-keygen \
	|| die 'Generate a new SSH key'

# 15. Disable remote fonts in Chromium
cat misc/default-flags >> /etc/chromium.d/default-flags \
	|| die 'Disable remote fonts in Chromium'
valid_reg /etc/chromium.d/default-flags

# 16. Install system-specific Xorg drivers
video_drivers=`apt-cache pkgnames xserver-xorg-video | grep -v dbg | sort -u` \
	|| die 'Find Xorg video driver candidates'
x=0
echo 'Select an Xorg Video Driver'
for video_driver in $video_drivers; do
	echo "  $x:" ${video_driver#xserver-xorg-video-}
	x=$((x+1))
done

echo "  $x: NONE"
none=$x

echo -n '> '; read x \
	|| die 'Read video driver selection'

if [ "$x" -ne "$none" ]; then
	y=0
	for video_driver in $video_drivers; do
		if [ "$x" -eq "$y" ]; then
			apt install "$video_driver" \
				|| die 'Install Xorg video driver'
			break
		fi
		y=$((y+1))
	done
fi

# 17. Configure global vimrc
sed -i 's/"syntax on/syntax on/' /etc/vim/vimrc \
	|| echo 'syntax on' >> /etc/vim/vimrc.local \
	|| die 'Add "syntax on" to global vimrc'
sed -i 's/"set background=dark/set background=dark/' /etc/vim/vimrc \
	|| echo 'set background=dark' >> /etc/vim/vimrc.local \
	|| die 'Add "set background=dark" to global vimrc'
sed -i 's/"set showmatch/set showmatch/' /etc/vim/vimrc \
	|| echo 'set showmatch' >> /etc/vim/vimrc.local \
	|| die 'Add "set showmatch" to global vimrc'
sed -i 's/"set ignorecase/set ignorecase/' /etc/vim/vimrc \
	|| echo 'set ignorecase' >> /etc/vim/vimrc.local \
	|| die 'Add "set ignorecase" to global vimrc'
sed -i 's/"set incsearch/set incsearch/' /etc/vim/vimrc \
	|| echo 'set incsearch' >> /etc/vim/vimrc.local \
	|| die 'Add "set incsearch" to global vimrc'
echo 'filetype plugin indent on' >> /etc/vim/vimrc.local \
	|| die 'Add "filetype plugin indent on" to global vimrc'
valid_reg /etc/vim/vimrc.local

# 18. Remove XDG user directories
sudo -u "$user" bash -c 'rmdir ~/{Desktop,Documents,Downloads,Music,Pictures,Public,Templates,Videos}' 2>/dev/null

# 19. Install Google Chrome
wget -o /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
	|| die 'Download google-chrome.deb'
dpkg -i /tmp/google-chrome.deb \
	|| die 'Start google-chrome.deb install'
apt -f install \
	|| die 'Finish google-chrome.deb install'
rm /tmp/google-chrome.deb
install -o root -g root -m 755 misc/chrome /usr/local/bin/chrome \
	|| die 'Add font fixing short-hand command for opening Google Chrome'

# 20. Setup binfmt_misc for executing Windows programs with Wine
install -o root -g root -m 644 misc/wine.conf /etc/binfmt.d/wine.conf \
	|| die 'Setup binfmt_misc for Windows programs'

# 21. Install FamiTracker (expects wine-binfmt to be installed)
install -o root -g root -m 755 misc/famitracker /usr/local/bin/famitracker \
	|| die 'Install FamiTracker'

# 22. Install DefleMask
apt install `cat pkgs_deflemask.txt` \
	|| die 'Install DefleMask dependencies'
tar xf -C /opt deflemask.tar.gz \
	|| die 'Extract DefleMask into /opt/deflemask'
install -o root -g root -m 755 misc/deflemask /usr/local/bin/deflemask \
	|| die 'Add an in-path DefleMask alias'
valid_tree /opt/deflemask

# 23. Select the correct Filezilla theme
sudo -u "$user" bash -c 'mkdir -p ~/.config/filezilla' \
	|| die 'Create Filezilla configuration directory'
install -o "$user" -g "$user" -m 644 misc/filezilla.xml "`echo ~$user`/.config/filezilla/filezilla.xml"
	|| die 'Install Filezilla configuration'

# 24. Share bash history between all instances
cat misc/bash-history.sh >> /etc/bash.bashrc \
	|| die 'Make bash history between all instances'
valid_reg /etc/bash.bashrc

# 25. Configure hwclock to assume local time
sed -i 's/UTC/LOCAL/' /etc/adjtime \
    || die 'Configure hwclock to assume local time'

# 26. Disable smooth scrolling
mkdir -p /etc/skel/.config/{chromium,google-chrome} \
	|| die 'Create Google Chrome/Chromium user skeleton configuration directories'
for dir in /etc/skel/.config/{chromium,google-chrome}; do
	cp misc/chrome-local-state "$dir/Local State" \
		|| die 'Copy Chrome "Local State" to skeleton configuration directories'
done
chmod 600 /etc/skel/.config/{chromium,google-chrome}/"Local State" \
	|| die 'Correct permission mask on Google Chrome/Chromium local state'
sudo -u "$user" bash -c 'mkdir -p ~/.config/{chromium,google-chrome}' \
	|| die 'Create user Google Chrome/Chromium configuration directories'
install -o "$user" -g "$user" -m 600 misc/chrome-local-state "`echo ~$user`/.config/chromium/Local State" \
	|| die 'Install Chromium configuration, disabling smooth scrolling'
install -o "$user" -g "$user" -m 600 misc/chrome-local-state "`echo ~$user`/.config/google-chrome/Local State" \
	|| die 'Install Google Chrome configuration, disabling smooth scrolling'

# 27. Install default desktop wallpaper
install -o "$user" -g "$user" -m 644 misc/bg.jpg "`echo ~$user`/.bg.jpg" \
    || die 'Install default desktop wallpaper'

echo 'Done.'
