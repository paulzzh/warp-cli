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

PKG=$(echo cloudflare-warp*.deb)

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

cp "$PKG" "$WORK/original.deb"

cd "$WORK"

# 解包 ar（保持 data.tar.zst 原样）
ar x original.deb

mkdir control
tar --zstd -xf control.tar.zst -C control

CONTROL=control/control

sed -Ei \
's/, *libayatana-appindicator3-1//g;
 s/, *libwebkit2gtk-4\.1-0//g' \
"$CONTROL"

# 固定时间戳
export SOURCE_DATE_EPOCH=0

find control -exec touch -d "@0" {} +

# 重新生成 control.tar.zst
rm control.tar.zst

tar \
    --sort=name \
    --owner=0 \
    --group=0 \
    --numeric-owner \
    --mtime="@0" \
    --pax-option=delete=atime,delete=ctime \
    -C control \
    -cf - . \
| zstd -19 --no-progress -q -o control.tar.zst

# 使用 deterministic ar
rm original.deb
ar rcD cloudflare-warp.deb \
    debian-binary \
    control.tar.zst \
    data.tar.zst

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
