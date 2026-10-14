#!/bin/sh
# Install the complete signage stack on a fresh Raspberry Pi OS Lite system.
# Run from a checked-out or copied repository root:
#   sudo ./pi-setup/install-signage.sh athens "Athens"
set -eu

say() { printf '\n==> %s\n' "$*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "Run with sudo."
[ "$#" -ge 1 ] && [ "$#" -le 2 ] || die "Usage: install-signage.sh SITE [SITE_LABEL]"

site=$1
site_label=${2:-$site}
case "$site" in
  ''|*[!a-z0-9-]*) die "Invalid site name: $site" ;;
esac
if ! printf '%s\n' "$site_label" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9 _-]*$'; then
  die "Invalid site label: $site_label"
fi

script_dir=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
repo_root=$(dirname "$script_dir")

if [ "$site" = "shallowford" ]; then
  content_path=
  content_dir=$repo_root
else
  content_path="sites/$site"
  content_dir="$repo_root/$content_path"
fi

for required in index.html ad.mp4 takeover.html takeover.png; do
  [ -s "$content_dir/$required" ] || die "Missing site content: $content_dir/$required"
done

[ ! -e /home/admin/signage/current ] || \
  die "An active signage installation already exists; use the migration runbook."
id admin >/dev/null 2>&1 || die "Required user does not exist: admin"

say "Installing minimal kiosk packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  cage \
  chromium \
  curl \
  dbus-user-session \
  file \
  fonts-liberation \
  grim \
  msmtp-mta \
  wlr-randr

say "Installing kiosk launcher and console autologin"
install -m 0755 -o admin -g admin "$repo_root/start-signage.sh" /home/admin/start-signage.sh
install -m 0644 -o admin -g admin "$repo_root/bash_profile.signage" /home/admin/.bash_profile
install -d -m 0755 /etc/systemd/system/getty@tty1.service.d
install -m 0644 "$repo_root/autologin.conf" \
  /etc/systemd/system/getty@tty1.service.d/autologin.conf

say "Installing signage commands"
for command in \
  signage-deploy-files \
  signage-control-sync \
  signage-display-mode \
  signage-email-configure \
  signage-health-email \
  signage-schedule \
  signage-takeover-watch \
  signage-update \
  signage-watchdog
do
  install -m 0755 "$script_dir/$command" "/usr/local/sbin/$command"
  sh -n "/usr/local/sbin/$command" || die "Syntax validation failed: $command"
done

say "Installing systemd units"
for unit in "$script_dir"/*.service "$script_dir"/*.timer; do
  install -m 0644 "$unit" "/etc/systemd/system/$(basename "$unit")"
done

say "Installing site and schedule configuration"
{
  echo "SITE=$site"
  echo "SITE_LABEL=\"$site_label\""
  echo "CONTENT_PATH=$content_path"
  echo "REPOSITORY=thelocalpixel-star/signage-pi-fleet"
  echo "REF=main"
} > /etc/default/signage-site
install -m 0644 "$script_dir/signage-schedule.conf" /etc/default/signage-schedule
printf 'MODE=normal\n' > /etc/default/signage-mode
chown root:root \
  /etc/default/signage-site \
  /etc/default/signage-schedule \
  /etc/default/signage-mode
chmod 0644 \
  /etc/default/signage-site \
  /etc/default/signage-schedule \
  /etc/default/signage-mode

say "Installing email transport configuration without credentials"
install -d -m 0700 /etc/signage-email
install -m 0600 "$script_dir/signage-email-msmtprc" /etc/signage-email/msmtprc
install -d -m 0755 -o admin -g admin /home/admin/signage/screenshots

say "Installing restricted passwordless sudo rules"
install -m 0440 "$script_dir/signage-sudoers" /etc/sudoers.d/signage
chown root:root /etc/sudoers.d/signage
visudo -c || die "sudoers validation failed"

say "Installing $site_label content as an atomic local release"
staging_dir=$(mktemp -d /tmp/signage-initial.XXXXXX)
trap 'rm -rf "$staging_dir"' EXIT HUP INT TERM
for content_file in index.html ad.mp4 takeover.html takeover.png; do
  cp "$content_dir/$content_file" "$staging_dir/$content_file"
done
cp "$content_dir/index.html" "$staging_dir/normal.html"
install -d -m 0755 -o admin -g admin /home/admin/signage
install -m 0644 -o admin -g admin \
  "$content_dir/takeover.png" /home/admin/signage/celebrate.png

systemctl daemon-reload
/usr/local/sbin/signage-deploy-files \
  "$staging_dir/index.html" "$staging_dir/ad.mp4" "local-$site-initial"
rm -rf "$staging_dir"
trap - EXIT HUP INT TERM

say "Starting the kiosk for verification"
systemctl restart getty@tty1.service
systemctl enable --now signage-takeover-watch.timer

# Enable the schedule and watchdog only after the first live-screen check.
# The GitHub updater remains disabled until this site's content is published.
# The health-email timer remains disabled until its root-only secret is set.
systemctl disable signage-schedule.timer signage-watchdog.timer \
  signage-update.timer signage-health-email.timer \
  signage-control-sync.timer 2>/dev/null || true

say "Fresh signage installation complete; automation is staged but not enabled."
