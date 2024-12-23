# TirtaAOSP - Automated Cloud Setup / Build Scripts
This folder is a container for any scripts that are used to automate the build process for my personal AOSP build, including provisioning the cloud infrastructure in Google Cloud (using gcloud CLI).

## Start auto setup on Google Cloud Platform (GCP)
1. Activate the Google Cloud Platform's Cloud Shell

2. Get the required shell scripts from this repo:
```bash
wget https://github.com/TIRTAGT/TirtaAOSP/raw/refs/heads/dev/.cloud-setup/functions.sh -O functions.sh
wget https://github.com/TIRTAGT/TirtaAOSP/raw/refs/heads/dev/.cloud-setup/gcp-infrastructure.sh -O gcp-infrastructure.sh
```

3. Make the script executable:
```bash
chmod +x gcp-infrastructure.sh functions.sh
```

4. Run the script:
```bash
./gcp-infrastructure.sh
```

## Check the startup-script log
1. Connect to the instance via SSH
2. Check the startup-script log in journald by running:
```bash
sudo journalctl -u google-startup-scripts.service
```