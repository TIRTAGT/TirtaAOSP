#!/bin/bash

# Check if we are on autobuild user
if [ "$(whoami)" != "autobuild" ]; then
	echo "error" "Please run this script as autobuild user."
	exit 1
fi

# Make sure we have functions.sh and it is executable
if [ ! -f functions.sh ]; then
	echo "error" "Cannot find functions.sh, exiting now."
	exit 1
fi

source functions.sh

# Go to /mnt/HDD_1
cd /mnt/HDD_1

# Check if we don't have platform-tools/
if [ ! -d platform-tools/ ]; then
	echo "Can't find platform-tools/ on the build disk, downloading Android SDK Platform Tools..."

	# Download Android SDK Platform Tools
	wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip

	# Extract the downloaded SDK Platform Tools
	unzip platform-tools-latest-linux.zip

	if [ $? -ne 0 ]; then
		echo "error" "Cannot extract the downloaded SDK Platform Tools, exiting now."
		exit 1
	fi

	# Remove the downloaded zip file
	rm platform-tools-latest-linux.zip

	# Add the platform-tools directory to the PATH environment variable via ~/.profile
	cat << "EOF" >> ~/.profile

# Add Android SDK Platform Tools to the PATH
if [ -d "/mnt/HDD_1/platform-tools" ]; then
	PATH="/mnt/HDD_1/platform-tools:$PATH"
fi

# Set the ANDROID_HOME environment variable
export ANDROID_HOME="/mnt/HDD_1/platform-tools"

EOF
fi

# Check if we don't have repo-bin/
if [ ! -d repo-bin/ ]; then
	echo "Can't find repo-bin/ on the build disk, downloading repo..."

	# Download repo
	mkdir -p repo-bin/
	curl https://storage.googleapis.com/git-repo-downloads/repo > repo-bin/repo
	chmod a+x repo-bin/repo

	if [ $? -ne 0 ]; then
		echo "error" "Cannot download repo, exiting now."
		exit 1
	fi

	# Add the platform-tools directory to the PATH environment variable via ~/.profile
	cat << "EOF" >> ~/.profile

# Add repo to the PATH
if [ -d "/mnt/HDD_1/repo-bin" ]; then
	PATH="/mnt/HDD_1/repo-bin:$PATH"
fi

EOF
fi

# Load the updated ~/.profile
source ~/.profile

# Check if we can use adb
adb --version 2> /dev/null

if [ $? -ne 0 ]; then
	echo "error" "ADB is not installed properly, please check the installation."
	exit 1
fi

# Check if we can use repo
repo --version 2> /dev/null

if [ $? -ne 0 ]; then
    echo "error" "Repo is not installed properly, please check the installation."
    exit 1
fi

git config --global user.email "autobuild@localhost"
git config --global user.name "AOSP Autobuild"
git config --global trailer.changeid.key "Change-Id"
git config --global color.ui false
git lfs install

export USE_CCACHE=1
export CCACHE_COMPRESS=1
export CCACHE_MAXSIZE=50G # 50 GB

# Make sure we are still on /mnt/HDD_1
cd /mnt/HDD_1

# Create folder for the android source
mkdir -p android/
cd android/

# Copy everything from /mnt/HDD_1/TirtaAOSP/aosp_sources/* into /mnt/HDD_1/android/
cp -r /mnt/HDD_1/TirtaAOSP/aosp_sources/* ./

# Create android signing keys
SUBJECT="/C=ID/ST=DKI Jakarta/L=Jakarta/O=Matthew Tirtawidjaja/OU=Matthew Tirtawidjaja/CN=Matthew Tirtawidjaja/emailAddress=aospbuild@example.com"
mkdir -p ~/.android-certs/
for x in releasekey platform shared media networkstack; do \
    ./development/tools/make_key ~/.android-certs/$x "$subject"; \
done

# Initialize the repo
repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs

git clone https://github.com/AndyCGYan/lineage_build_unified lineage_build_unified -b lineage-19.1
git clone https://github.com/AndyCGYan/lineage_patches_unified lineage_patches_unified -b lineage-19.1

# Actually run the build
#bash lineage_build_unified/buildbot_unified.sh treble A64VN