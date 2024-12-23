#!/bin/bash

# Set default value for variables
BUILD_DIR="${BUILD_DIR:-/mnt/HDD_1}"
TIRTA_AOSP_DIR="${TIRTA_AOSP_DIR:-$BUILD_DIR/TirtaAOSP}"
SDK_PLATFORM_TOOLS_DIR="${SDK_PLATFORM_TOOLS_DIR:-$BUILD_DIR/platform-tools}"
REPO_BIN_DIR="${REPO_BIN_DIR:-$BUILD_DIR/repo-bin}"

# Check if we are on autobuild user
if [ "$(whoami)" != "autobuild" ]; then
	echo "error" "Please run this script as autobuild user."
	exit 1
fi

# Go to $TIRTA_AOSP_DIR/.cloud-setup
cd "$TIRTA_AOSP_DIR/.cloud-setup"

# Make sure we have functions.sh
if [ ! -f functions.sh ]; then
	echo "error" "Cannot find functions.sh, exiting now."
	exit 1
fi

source functions.sh

# Apply all patches for the $TIRTA_AOSP_DIR/aosp_source
cd "$TIRTA_AOSP_DIR/aosp_source"
git apply ./*.patch

# Go back to $BUILD_DIR
cd "$BUILD_DIR"

# Check if we don't have $SDK_PLATFORM_TOOLS_DIR
if [ ! -d "$SDK_PLATFORM_TOOLS_DIR" ]; then
	echo "Can't find platform-tools/ on the build location, downloading Android SDK Platform Tools..."

	# Download Android SDK Platform Tools
	wget https://dl.google.com/android/repository/platform-tools-latest-linux.zip -O "$BUILD_DIR/platform-tools-latest-linux.zip"

	# Extract the downloaded SDK Platform Tools
	unzip platform-tools-latest-linux.zip

	if [ $? -ne 0 ]; then
		echo "error" "Cannot extract the downloaded SDK Platform Tools, exiting now."
		exit 1
	fi

	# Remove the downloaded zip file
	rm platform-tools-latest-linux.zip

	# Add the platform-tools directory to the PATH environment variable via ~/.profile
	cat << EOF >> ~/.profile

# Add Android SDK Platform Tools to the PATH
if [ -d "$SDK_PLATFORM_TOOLS_DIR" ]; then
	PATH="$SDK_PLATFORM_TOOLS_DIR:\$PATH"
fi

# Set the ANDROID_HOME environment variable
export ANDROID_HOME="$SDK_PLATFORM_TOOLS_DIR"

EOF
fi

# Check if we don't have $REPO_BIN_DIR
if [ ! -d "$REPO_BIN_DIR" ]; then
	echo "Can't find repo-bin/ on the build location, downloading repo..."

	# Download repo
	mkdir "$REPO_BIN_DIR"
	curl https://storage.googleapis.com/git-repo-downloads/repo > "$REPO_BIN_DIR/repo"
	chmod a+x "$REPO_BIN_DIR/repo"

	if [ $? -ne 0 ]; then
		echo "error" "Cannot download repo, exiting now."
		exit 1
	fi

	# Add the platform-tools directory to the PATH environment variable via ~/.profile
	cat << EOF >> ~/.profile

# Add repo to the PATH
if [ -d "$REPO_BIN_DIR" ]; then
	PATH="$REPO_BIN_DIR:\$PATH"
fi

EOF
fi

# Load the updated ~/.profile
source ~/.profile

# Make sure $ANDROID_HOME is set
if [ -z "$ANDROID_HOME" ]; then
    echo "error" "ANDROID_HOME is not set, although it should be set by now. Please check the installation."
    exit 1
fi

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

# Check if we can use git
git --version 2> /dev/null

if [ $? -ne 0 ]; then
    echo "error" "Git is not installed properly, please check the installation."
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

# Make sure we are still on the build directory
cd "$BUILD_DIR"

# Create folder for the android source
mkdir -p android/
cd android/

# Copy everything from /mnt/HDD_1/TirtaAOSP/aosp_source/* into /mnt/HDD_1/android/
cp -r "$TIRTA_AOSP_DIR/aosp_source/"* .

if [ $? -ne 0 ]; then
	echo "error" "Cannot pre-init some files from TirtaAOSP repo, exiting now."
	exit 1
fi


# Check if we don't have ~/.android-certs
if [ ! -f ~/.android-certs ]; then
	# Create android signing keys
	SUBJECT="/C=ID/ST=DKI Jakarta/L=Jakarta/O=Matthew Tirtawidjaja/OU=Matthew Tirtawidjaja/CN=Matthew Tirtawidjaja/emailAddress=aospbuild@example.com"
	mkdir -p ~/.android-certs/
	chmod +x ./development/tools/make_key

	export password="$(openssl rand -base64 64)"
	echo "$password" > ~/.android-certs/password
	chmod 600 ~/.android-certs/password
	
	for x in releasekey platform shared media networkstack; do \
		./development/tools/make_key ~/.android-certs/$x "$subject"; \
	done

	unset password
fi

# Initialize the repo
repo init -u https://github.com/LineageOS/android.git -b lineage-19.1 --git-lfs

git clone https://github.com/AndyCGYan/lineage_build_unified lineage_build_unified -b lineage-19.1
git clone https://github.com/AndyCGYan/lineage_patches_unified lineage_patches_unified -b lineage-19.1

# Actually run the build
#bash lineage_build_unified/buildbot_unified.sh treble A64VN