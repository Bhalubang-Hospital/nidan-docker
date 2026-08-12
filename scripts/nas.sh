#!/bin/bash

# 1. Turn off history expansion so the '!' doesn't break the password
set +H

# 2. Define your password variables safely
NAS_PASS='Bhalubang_EHR#2026!'

# 3. Run rsync using full absolute paths for safety
/usr/bin/sshpass -p "$NAS_PASS" /usr/bin/rsync -avz -e "/usr/bin/ssh -l nidan -o StrictHostKeyChecking=no" /home/bhalubang/nidan-docker/backup-artifacts/ nidan@192.168.10.25:/share/Public/DB_Backup/
