#!/bin/bash
# TWRP build script
# For github actions
#
# Copyright(c) 2021 Hendra Manudinata.

#set -eo pipefail


# Setup environment
setup_env() {
	sudo DEBIAN_FRONTEND=noninteractive apt-get install bison build-essential \
	curl flex git gnupg gperf ccache \
	liblz4-tool libncurses5-dev libsdl1.2-dev \
	libxml2 libxml2-utils lzop pngcrush \
	schedtool squashfs-tools xsltproc zip zlib1g-dev \
	build-essential kernel-package libncurses5-dev bzip2 git \
	python wget gcc g++ curl sudo libssl-dev openssl -y


	#export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx3g"

	#sudo curl --create-dirs -L -o /usr/local/bin/repo -O -L https://storage.googleapis.com/git-repo-downloads/repo
	#sudo chmod a+rx /usr/local/bin/repo

	sudo apt-get clean
	sudo rm -rf /var/cache/apt/*
	sudo rm -rf /var/lib/apt/lists/*
	sudo rm -rf /tmp/*

	sudo ln -sf /usr/share/zoneinfo/Asia/Dhaka /etc/localtime

	# Claim more diskspace
	# Thanks to @yukosky

	sudo swapoff -av
	sudo rm -f /swapfile

	sudo rm -rf /usr/share/dotnet

	sudo rm -rf "/usr/local/share/boost"
	sudo rm -rf "$AGENT_TOOLSDIRECTORY"
	sudo swapoff -av
	sudo rm -rf /mnt/swapfile
	sudo dpkg --purge '^ghc-8.*' '^dotnet-.*' '^llvm-.*' 'php.*' azure-cli google-cloud-sdk '^google-.*' hhvm google-chrome-stable firefox '^firefox-.*' powershell mono-devel '^account-plugin-.*' account-plugin-facebook account-plugin-flickr account-plugin-twitter account-plugin-windows-live aisleriot brltty duplicity empathy empathy-common example-content gnome-accessibility-themes gnome-contacts gnome-mahjongg gnome-mines gnome-orca gnome-screensaver gnome-sudoku gnome-video-effects gnomine landscape-common libreoffice-avmedia-backend-gstreamer libreoffice-base-core libreoffice-calc libreoffice-common libreoffice-core libreoffice-draw libreoffice-gnome libreoffice-gtk libreoffice-impress libreoffice-math libreoffice-ogltrans libreoffice-pdfimport libreoffice-style-galaxy libreoffice-style-human libreoffice-writer libsane libsane-common python3-uno rhythmbox rhythmbox-plugins rhythmbox-plugin-zeitgeist sane-utils shotwell shotwell-common telepathy-gabble telepathy-haze telepathy-idle telepathy-indicator telepathy-logger telepathy-mission-control-5 telepathy-salut totem totem-common totem-plugins printer-driver-brlaser printer-driver-foo2zjs printer-driver-foo2zjs-common printer-driver-m2300w printer-driver-ptouch printer-driver-splix
	# Bonus
	sudo dd if=/dev/zero of=swap bs=4k count=1048576
	sudo mkswap swap
	sudo swapon swap
}

# Clone source
clone_source() {
	cd ~
	git clone https://github.com/0x300T/samsung_a10s --depth=1 samsung 

}

# Clone DT
clone_toolchain() {
	cd ~
    mkdir clang && wget -q https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/android-10.0.0_r3/clang-r353983c.tar.gz -O clang.tar.gz && tar -xzf clang.tar.gz -C clang && rm clang.tar.gz
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 --depth=1 toolchain
    git clone https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 --depth=1 toolchain-arm
   }

# Start build
start_build() {
       BUILD_START=$(date +"%s")
       cd ~/samsung
       export PATH="$HOME/clang/bin:$HOME/toolchain/bin:$HOME/toolchain-arm/bin:$PATH"
       export ANDROID_MAJOR_VERSION=q
       export ARCH=arm64
       export SUBARCH=arm64
       make clean && make mrproper O=output
       make KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y a10s_defconfig O=output
       make KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y -j$(nproc --all) CC=$HOME/clang/bin/clang CROSS_COMPILE=$HOME/toolchain/bin/aarch64-linux-android- CLANG_TRIPLE=$HOME/clang/bin/aarch64-linux-gnu- CROSS_COMPILE_ARM32=$HOME/toolchain-arm/bin/arm-linux-androideabi- O=output

	   BUILD_END=$(date +"%s")
	   DIFF=$(($BUILD_END - $BUILD_START))
}

# Fancy Telegram function

# Send text (helper)
function tg_sendText() {
	curl -s "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
		-d "parse_mode=html" \
		-d text="${1}" \
		-d chat_id=$CHAT_ID \
		-d "disable_web_page_preview=true"
}

# Send info
tg_sendInfo() {
	tg_sendText "<b>Kernel Build Started!</b>
	<b>💻 Started on:</b> Github Actions
	<b>📆  Date:</b> $(date +%A,\ %d\ %B\ %Y\ %H:%M:%S)"
}

# Telegram status: Prepare
tg_sendPrepareStatus() {
	tg_sendText "<b>$(date +%H:%M:%S):</b> Preparing Environment"
}

# Telegram status: Download source
tg_sendSyncSourceStatus() {
	tg_sendText "<b>$(date +%H:%M:%S):</b> Cloning toolchains"
}

# Telegram status: Clone tree
tg_sendCloneTreeStatus() {
	tg_sendText "<b>$(date +%H:%M:%S):</b> Cloning Kernel Source"
}

# Telegram status: Build
tg_sendBuildStatus() {
	tg_sendText "<b>$(date +%H:%M:%S):</b> Building"
}

# Telegram status: Done
tg_sendDoneStatus() {
	tg_sendText "<b>Build done successfully! 🎉</b>
	<b>Time build:</b> $(($DIFF / 60))m $(($DIFF % 60))s"
}

# Telegram send file
tg_sendFile() {
	curl -F chat_id=$CHAT_ID -F document=@${1} -F parse_mode=markdown https://api.telegram.org/bot$BOT_TOKEN/sendDocument
}

# Send image
send_image() {
	cd ~/samsung/output/arch/arm64/boot
	for i in Image.gz-dtb Image.gz Image; do
		tg_sendFile $i
	done
}

# Error function
abort() {
	errorvalue=$?
	tg_sendText "Build error! Check github actions log bruh"
	exit $errorvalue
}
trap 'abort' ERR;

# Finally, call the function
tg_sendInfo;
tg_sendPrepareStatus;
setup_env;
tg_sendSyncSourceStatus;
clone_source;
tg_sendCloneTreeStatus;
clone_tree;
tg_sendBuildStatus;
start_build;
tg_sendDoneStatus;
send_image;