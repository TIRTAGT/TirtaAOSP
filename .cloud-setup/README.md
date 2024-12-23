

# Start auto setup on Google Cloud Platform (GCP)
1. Activate the Google Cloud Platform's Cloud Shell

2. Get the required shell scripts from this repo:
```bash
wget https://github.com/TIRTAGT/TirtaAOSP/raw/refs/heads/dev/.cloud-setup/functions.sh
wget https://github.com/TIRTAGT/TirtaAOSP/raw/refs/heads/dev/.cloud-setup/gcp-infrastructure.sh
```

3. Make the script executable:
```bash
chmod +x gcp-infrastructure.sh functions.sh
```

4. Run the script:
```bash
./gcp-infrastructure.sh
```