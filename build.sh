set -e
cd /github/home
echo Install dependencies.
apt-get update > /dev/null 2>&1
apt-get install -y curl gpg 2>&1
# Add cloudflare gpg key
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | gpg --yes --dearmor --output /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
# Add this repo to your apt repositories
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ trixie main" | tee /etc/apt/sources.list.d/cloudflare-client.list
# Install
apt-get update && apt-get download cloudflare-warp

mkdir -p work/pkg
dpkg-deb -R cloudflare-warp*.deb work/pkg
CONTROL=work/pkg/DEBIAN/control
sed -Ei \
's/, *libayatana-appindicator3-1//g;
 s/, *libwebkit2gtk-4\.1-0//g' \
"$CONTROL"
dpkg-deb -b work/pkg cloudflare-warp.deb

hash=$(sha256sum cloudflare-warp.deb | awk '{print $1}')
patch=$(cat /github/workspace/patch)
minor=$(cat /github/workspace/minor)
if [[ $hash != $(cat /github/workspace/hash) ]]; then
  echo $hash > /github/workspace/hash
  if [[ $GITHUB_EVENT_NAME == push ]]; then
    patch=0
    minor=$(($(cat /github/workspace/minor)+1))
    echo $minor > /github/workspace/minor
  else
    patch=$(($(cat /github/workspace/patch)+1))
  fi
  echo $patch > /github/workspace/patch
  change=1
  echo This is a new version.
else
  echo This is an old version.
fi
echo -e "hash=$hash\npatch=$patch\nminor=$minor\nchange=$change" >> $GITHUB_ENV
