#!/bin/bash

# Setup environment
die() { echo FAILURE: "$@" 1>&2; exit 1; }

cd `dirname "$0"` \
	|| die "Enter script's directory"

# 0. Fix apt
cp misc/sources.list /etc/apt/sources.list \
	|| die 'Select repositories'
install -o root -g root -m 644 misc/10no-check-valid-until /etc/apt/apt.conf.d/10no-check-valid-until \
	|| die 'Fix repository "valid until" behaviour'

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
user=`getent passwd 1000 | cut -d: -f1` \
	|| die "Find default user's username"
adduser "$user" sudo \
	|| die 'Add default user to sudo group'

# 3. Fix fonts
apt remove fonts-dejavu-core ttf-bitstream-vera fonts-droid \
	|| die 'Uninstall awful fonts'
rm /etc/fonts/conf.d/{10-scale-bitmap-fonts.conf,70-no-bitmaps.conf}
sed -i 's/Bitstream Vera/Liberation/; s/Liberation Sans Mono/Liberation Mono/' /etc/fonts/conf.d/*-latin.conf \
	|| die 'Configure latin fonts'
install -o root -g root -m 644 misc/local.conf /etc/fonts/local.conf \
	|| die 'Fix font aliasing and hinting'

# 4. Install Gohu and Tahoma fonts
cp -rp gohu/ /usr/share/fonts/X11/ \
	|| die 'Copy gohu/'
cp -rp tahoma/ /usr/share/fonts/truetype/ \
	|| die 'Copy tahoma/'
chown -R root:root /usr/share/fonts/X11/gohu/ /usr/share/fonts/truetype/tahoma/ \
	|| die 'Ensure proper ownership of gohu/ and tahoma/'
install -o root -g root -m 644 misc/20-fonts.conf /usr/share/X11/xorg.conf.d/20-fonts.conf \
	|| die 'Add gohu/ to Xorg FontPath'

# 5. Install Windows 2000 Theme
cp -rp win2k/ /usr/share/themes/ \
	|| die 'Copy win2k/'
chown -R root:root /usr/share/themes/win2k/ \
	|| die 'Ensure proper ownership of win2k/'

# 6. Configure XTerm
rm /etc/X11/Xresources/x11-common
install -o root -g root -m 644 misc/x11-common /etc/X11/Xresources/x11-common \
	|| die 'Configure XTerm'

# 7. Fix key repeat
install -o root -g root -m 644 misc/70-key-repeat /etc/X11/Xsession.d/70-key-repeat \
	|| die 'Fix key repeat'

# 8. Configure OpenBox
cp -rp openbox/ /etc/xdg/ \
	|| die 'Copy openbox/'
chown -R root:root /etc/xdg/openbox/ \
	|| die 'Ensure proper ownership of openbox/'

# 9. Configure Tint2
install -o root -g root -m 644 misc/tint2rc /etc/xdg/tint2/tint2rc \
	|| die 'Configure Tint2'

# 10. Update font cache
fc-cache -f -v \
	|| die 'Update font cache'

# 11. Eliminate password failure delays (given physical access)
sed -i '/pam_unix.so/ s/$/ nodelay/' /etc/pam.d/common-auth \
	|| die 'Eliminate password failure delays'

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
chmod 644 /etc/chromium.d/default-flags \
	|| die 'Ensure proper permission mode of Chromium default-flags'
chown root:root /etc/chromium.d/default-flags \
	|| die 'Ensure proper owner of Chromium default-flags'

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
chmod 644 /etc/vim/vimrc.local
	|| die 'Ensure proper permission mode of global vimrc'
chown root:root /etc/vim/vimrc.local
	|| die 'Ensure proper owner of global vimrc'

# 18. Remove pointless default user skeleton
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

echo 'Done.'
