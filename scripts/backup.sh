#!/bin/bash

# Create backup directory if it doesn't exist
mkdir -p backup

# Generate timestamp for backup filename
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create tar.gz backup of data directory
tar -czf "backup/data_backup_${TIMESTAMP}.tar.gz" data/

echo "Backup created: backup/data_backup_${TIMESTAMP}.tar.gz"