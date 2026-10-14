#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temp_dir=$(mktemp -d /tmp/test-signage-update.XXXXXX)
trap 'rm -rf "$temp_dir"' EXIT HUP INT TERM

fixture="$temp_dir/repository"
mkdir -p "$fixture/sites/athens"

make_site() {
  directory=$1
  label=$2
  printf '<!doctype html><title>%s normal</title>\n' "$label" > "$directory/index.html"
  printf '\000\000\000\030ftypisom\000\000\002\000isomiso2fake %s video\n' "$label" > "$directory/ad.mp4"
  printf '<!doctype html><title>%s takeover</title>\n' "$label" > "$directory/takeover.html"
  printf 'fake %s image\n' "$label" > "$directory/takeover.png"
}

make_site "$fixture" shallowford
make_site "$fixture/sites/athens" athens

deploy_log="$temp_dir/deploy.log"
fake_deploy="$temp_dir/fake-deploy"
cat > "$fake_deploy" <<'EOF'
#!/bin/sh
set -eu
grep -q "$EXPECTED_PAGE" "$1"
grep -q "$EXPECTED_VIDEO" "$2"
[ -s "$(dirname "$1")/normal.html" ]
printf '%s\n' "$3" > "$DEPLOY_LOG"
EOF
chmod +x "$fake_deploy"

run_update() {
  expected_page=$1
  expected_video=$2
  site_config=$3
  mode_config=$4
  action=${5:-run}

  (
    export EXPECTED_PAGE="$expected_page"
    export EXPECTED_VIDEO="$expected_video"
    export DEPLOY_LOG="$deploy_log"
    export SIGNAGE_CONTENT_BASE_URL="file://$fixture"
    export SIGNAGE_SITE_CONFIG_FILE="$site_config"
    export SIGNAGE_MODE_CONFIG_FILE="$mode_config"
    export SIGNAGE_DEPLOY_COMMAND="$fake_deploy"
    export SIGNAGE_CURL_RETRY=0
    export SIGNAGE_CURL_RETRY_DELAY=0
    if [ "$action" = "check" ]; then
      "$repo_root/pi-setup/signage-update" --check
    else
      "$repo_root/pi-setup/signage-update"
    fi
  )
}

# No config must preserve the deployed Shallowford root behavior.
run_update 'shallowford normal' 'shallowford video' \
  "$temp_dir/no-site-config" "$temp_dir/no-mode-config"
grep -q '^github-main-shallowford-normal$' "$deploy_log"

cat > "$temp_dir/site-config" <<'EOF'
SITE=athens
CONTENT_PATH=sites/athens
REPOSITORY=thelocalpixel-star/shallowford-pi
REF=main
EOF
printf 'MODE=takeover\n' > "$temp_dir/mode-config"

run_update 'athens takeover' 'athens video' \
  "$temp_dir/site-config" "$temp_dir/mode-config"
grep -q '^github-main-athens-takeover$' "$deploy_log"

printf 'not-called\n' > "$deploy_log"
run_update 'athens takeover' 'athens video' \
  "$temp_dir/site-config" "$temp_dir/mode-config" check
grep -q '^not-called$' "$deploy_log"

# An incomplete location must fail before the deploy command is invoked.
rm "$fixture/sites/athens/ad.mp4"
printf 'not-called\n' > "$deploy_log"
if run_update 'athens takeover' 'athens video' \
  "$temp_dir/site-config" "$temp_dir/mode-config" 2>/dev/null; then
  echo 'incomplete Athens content unexpectedly succeeded' >&2
  exit 1
fi
grep -q '^not-called$' "$deploy_log"

printf 'signage-update tests passed\n'
