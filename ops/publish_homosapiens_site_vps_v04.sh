#!/usr/bin/env sh
set -eu
echo "HOMOSAPIENS_SITE_PUBLISH_V04_START"
curl -fsSL https://raw.githubusercontent.com/milenapsa/homosapiens-site/main/ops/publish_homosapiens_site_vps_v03.sh -o /tmp/publish-v03.sh
sed -i 's/from pathib import Path/from pathlib import Path/' /tmp/publish-v03.sh
sh /tmp/publish-v03.sh
echo "HOMOSAPIENS_SITE_PUBLISH_V04_OK"
