#!/bin/bash

DEFAULT_PROJECT=""
DEFAULT_REGION="us-central1"
DEFAULT_ZONE="$DEFAULT_REGION-a"

COMPUTE_ENGINE_TYPE="e2-highmem-8"

EXTRA_SSH_PUBLIC_KEY="""
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEW4h9US1yzaueaROG2FwyR2YLedNWHOWzmbRxNEtURD
"""

export CLOUDSDK_CORE_DISABLE_PROMPTS=1

#region Initialization

# Make sure we have functions.sh and it is executable
if [ ! -f "./functions.sh" ]; then
	echo "error" "Cannot find functions.sh, exiting now."
	exit 1
fi

source ./functions.sh

mkdir tirta_aosp-cloud_setup_cache/
if [ $? -ne 0 ]; then
	echo "error" "Cannot create cache directory, exiting now."
	exit 1
fi

cd tirta_aosp-cloud_setup_cache/

# Check if gcloud is installed
gcloud version > /dev/null
if [ $? -ne 0 ]; then
	echo "error" "Cannot find gcloud, please install it first."
	exit 1
fi

# Check if Google Cloud SDK is authenticated
gcloud auth print-access-token > /dev/null
if [ $? -ne 0 ]; then
	echo "error" "Google Cloud SDK is not authenticated, please run 'gcloud auth login' first."
	exit 1
fi

# Check if we have default project selected
DEFAULT_PROJECT=$(gcloud config get-value project)
if [ $? -ne 0 ]; then
    echo "error" "No default project selected, please run 'gcloud config set project <project-id>' first."
	exit 1
fi

DEFAULT_EXTRA_SSH_USER=$(whoami)

#endregion

echo "Creating service account for the Compute Engine..."

gcloud iam service-accounts create "custom-service-account" \
    --display-name "Custom Service Account" \
	--description "Custom Service Account for Compute Engine"

if [ $? -ne 0 ]; then
	echo "error" "Cannot create service account, exiting now."
	exit 1
fi

SERVICE_ACCOUNT_EMAIL="custom-service-account@$DEFAULT_PROJECT.iam.gserviceaccount.com"

echo "Trying to enable Compute Engine API..."

gcloud services enable compute.googleapis.com
if [ $? -ne 0 ]; then
	echo "error" "Cannot enable Compute Engine API, exiting now."
	exit 1
fi

sleep 30
echo "success" "Compute Engine API is enabled, waiting for 30 seconds to make sure the change is propagated..."

echo "Writing out additional ssh keys to a file for metadata..."

# For each line of $EXTRA_SSH_PUBLIC_KEY, write it out to extra_ssh_keys.txt
echo "$EXTRA_SSH_PUBLIC_KEY" | while IFS= read -r line; do
	# If $line is empty, skip
	if [ -z "$line" ]; then
		continue
	fi

	echo "$DEFAULT_EXTRA_SSH_USER:$line" >> extra_ssh_keys.txt
done

echo "success" "Additional ssh keys are written out to extra_ssh_keys.txt"

echo "Writing out startup script to a file for metadata..."

cat << "EOF" >> startup_script.sh

#!/bin/bash

# If we already have /mnt/HDD_1, then we don't need to setup anything again
if [ -d "/mnt/HDD_1" ]; then
	exit 0
fi

sudo apt update
sudo apt upgrade -y
sudo apt install -y unzip

# Create GPT partition table for /dev/sdb
sudo parted -s /dev/sdb mklabel gpt

# Create a single partition table for /dev/sdb covering the whole disk space
sudo parted -s /dev/sdb mkpart primary 0% 100%

# Format /dev/sdb1 as an EXT4 filesystem
sudo mkfs.ext4 /dev/sdb1

# Auto mount /dev/sdb1 to /mnt/HDD_1
sudo mkdir /mnt/HDD_1
echo "/dev/sdb1 /mnt/HDD_1 ext4 defaults 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# Create a new user named "autobuild" for the build server
sudo useradd --system --create-home --shell /bin/bash autobuild

# Add autobuild user to the sudo group
sudo usermod -aG sudo autobuild

cd /mnt/HDD_1

# Install libncurses5-dev
sudo wget http://archive.ubuntu.com/ubuntu/pool/universe/n/ncurses/libtinfo5_6.3-2_amd64.deb 
sudo dpkg -i libtinfo5_6.3-2_amd64.deb
sudo rm -f libtinfo5_6.3-2_amd64.deb

sudo apt install -y git git-lfs xz-utils curl bc bison build-essential flex g++-multilib gcc-multilib \
	gnupg gperf libxml2 lib32z1-dev liblz4-tool libsdl1.2-dev imagemagick git lunzip lzop schedtool \
	squashfs-tools xsltproc zip zlib1g-dev python-is-python3 perl xmlstarlet virtualenv rr jq pngcrush \
	libxml2 openjdk-8-jdk openjdk-11-jdk-headless

# Clone the TIRTAGT AOSP repository
sudo git clone https://github.com/TIRTAGT/TirtaAOSP.git

# Move to the TIRTAGT AOSP repository
cd TirtaAOSP/

# Checkout to the dev branch
sudo git checkout dev

# Add the executable bit to .cloud-setup/*.sh for the owner
sudo chmod 744 .cloud-setup/*.sh

# Set autobuild as the owner of /mnt/HDD_1
sudo chown -R autobuild:autobuild /mnt/HDD_1

# Execute build.sh
sudo su -c "bash /mnt/HDD_1/TirtaAOSP/.cloud-setup/build.sh" autobuild

EOF

echo "Trying to create a new Compute Engine instance..."

if [ -z "$COMPUTE_ENGINE_TYPE" ]; then
    COMPUTE_ENGINE_TYPE="n1-standard-1"
fi

gcloud compute instances create aosp-build-instance \
    --zone="$DEFAULT_ZONE" \
	--machine-type="$COMPUTE_ENGINE_TYPE" \
    --network-interface="network-tier=STANDARD,stack-type=IPV4_ONLY,subnet=default" \
	--maintenance-policy="MIGRATE" \
    --provisioning-model="STANDARD" \
	--service-account="$SERVICE_ACCOUNT_EMAIL" \
	--scopes="https://www.googleapis.com/auth/devstorage.read_only,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/monitoring.write,https://www.googleapis.com/auth/service.management.readonly,https://www.googleapis.com/auth/servicecontrol,https://www.googleapis.com/auth/trace.append" \
	--create-disk="auto-delete=yes,boot=yes,device-name=instance-20241222-201443,image=projects/ubuntu-os-cloud/global/images/ubuntu-2404-noble-amd64-v20241219,mode=rw,size=20,type=pd-balanced" \
	--create-disk="auto-delete=yes,device-name=aosp-build-disk,mode=rw,name=aosp-build-disk,size=400,type=pd-standard" \
	--no-shielded-secure-boot \
	--shielded-vtpm \
	--shielded-integrity-monitoring \
	--reservation-affinity="any" \
	--metadata-from-file="ssh-keys=extra_ssh_keys.txt,startup-script=startup_script.sh"

if [ $? -ne 0 ]; then
	echo "error" "Cannot create Compute Engine instance, exiting now."
	exit 1
fi

echo "success" "Compute Engine instance has been created successfully!"
