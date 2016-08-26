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
rm /etc/fonts/conf.d/{10-scale-bitmap-fonts.conf,70-no-bitmaps.conf} \
	|| die 'Enable bitmap fonts'
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
rm /etc/X11/Xresources/x11-common \
	|| die 'Remove x11-common'
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
fc-cache -f -v

# 11. Eliminate password failure delays (given physical access)
sed -i '/pam_unix.so/ s/$/ nodelay/' /etc/pam.d/common-auth

echo 'Done.'
