# Multi-site rollout record

The Athens and Shallowford migration was completed on October 14, 2026. This
record preserves the safety sequence for future locations and remote upgrades.

## Safety invariants

- Keep a remote location's existing content path in place until its new path is
  active and verified.
- Never reboot Shallowford as part of an updater-only migration.
- Never activate partially downloaded content.
- Keep the active release plus the immediately previous active release.
- Test new scripts on a reachable canary before installing them on a remote Pi.
- Do not remove a legacy content path until every affected Pi uses
  `CONTENT_PATH=sites/<site>`.

## Stage 1: local preparation

1. Add all four location files under `sites/<site>/`.
2. Run `tests/test-signage-update.sh` and shell syntax checks.
3. Review the diff and confirm existing location files are unchanged.

No GitHub or Pi changes occur in this stage.

## Stage 2: canary

1. Push the reviewed work to a feature branch only after explicit approval.
2. Configure the canary with its `SITE`, `CONTENT_PATH=sites/<site>`, and an
   immutable 40-character commit SHA in `REF`.
3. Run `sudo signage-update --check` before the first activation.
4. Activate the canary, then verify its screenshot, heartbeat, timers, temperature,
   throttling state, active release, rollback release, SSH, and Pi Connect.
5. For high-risk changes, observe a scheduled 8:00 AM update before promotion.

## Stage 3: Shallowford read-only audit

Collect these without changing the Pi:

```bash
cat /etc/default/signage-mode
sha256sum /usr/local/sbin/signage-update /usr/local/sbin/signage-deploy-files
readlink -f /home/admin/signage/current
ls -lh /home/admin/signage/releases
systemctl list-timers 'signage-*' --no-pager
curl -s --max-time 10 http://127.0.0.1:9222/json/list
vcgencmd get_throttled
vcgencmd measure_temp
rpi-connect status
```

Review the audit and canary results before requesting permission to
write anything on Shallowford.

## Stage 4: Shallowford migration

After explicit approval for this device and action:

1. Save dated copies of the two installed updater/deployer scripts.
2. Install the reviewed scripts without changing content or display mode.
3. Configure `SITE=shallowford` and `CONTENT_PATH=sites/shallowford`.
4. Run `sudo signage-update --check`. This downloads and validates the
   Shallowford content but does not invoke the deployer or restart the kiosk.
5. Run the updater normally only after the check succeeds.
6. Verify the live heartbeat and health email before ending the session.
7. Leave the dated script copies in place until the next scheduled update has
   also succeeded.

If any check fails, stop. The active release remains unchanged, and the saved
scripts provide the rollback path.

## Stage 5: promotion

Merge to `main` only after separate approval and after all displays have been
verified. Change the canary from its pinned SHA to `REF=main`. Remove any legacy
content path only after the installed updater has successfully activated the
new site directory and passed the post-update checks.

## 2026-10-14 result

- Athens and Shallowford use `REPOSITORY=thelocalpixel-star/signage-pi-fleet`,
  `REF=main`, and their own `sites/<site>` content paths.
- Both Pis passed normal, default takeover, custom takeover, revert-timer
  cancellation, Chromium heartbeat, health-email, thermal, and throttling
  checks.
- Shallowford's hosted control sync is enabled. Athens' control sync is tracked
  separately from the site-content migration.
- The duplicated Shallowford files at the repository root were removed after
  successful remote activation.
