# Multi-site rollout

This rollout treats Shallowford as a remote production display with no
physical recovery path. Repository changes and Pi installation are separate
approval gates.

## Safety invariants

- Keep Shallowford's root content files in place throughout the migration.
- Never reboot Shallowford as part of an updater-only migration.
- Never activate partially downloaded content.
- Keep the active release plus the immediately previous active release.
- Test new scripts on Athens before installing them on Shallowford.
- Do not add large Athens media to `main` while Shallowford still uses the
  archive-based updater; it would download every site's media.

## Stage 1: local preparation

1. Add all four Athens files under `sites/athens/`.
2. Run `tests/test-signage-update.sh` and shell syntax checks.
3. Review the diff and confirm the Shallowford root files are unchanged.

No GitHub or Pi changes occur in this stage.

## Stage 2: Athens canary

1. Push the reviewed work to a feature branch only after explicit approval.
2. Configure Athens with `SITE=athens`, `CONTENT_PATH=sites/athens`, and an
   immutable 40-character commit SHA in `REF`.
3. Run `sudo signage-update --check` before the first activation.
4. Activate Athens, then verify its screenshot, heartbeat, timers, temperature,
   throttling state, active release, rollback release, SSH, and Pi Connect.
5. Observe at least one scheduled 8:00 AM update before promoting the change.

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

Review the audit and Athens canary results before requesting permission to
write anything on Shallowford.

## Stage 4: Shallowford migration

After explicit approval for this device and action:

1. Save dated copies of the two installed updater/deployer scripts.
2. Install the reviewed scripts without changing content or display mode.
3. Configure `SITE=shallowford` and an empty `CONTENT_PATH`.
4. Run `sudo signage-update --check`. This downloads and validates the root
   Shallowford content but does not invoke the deployer or restart the kiosk.
5. Run the updater normally only after the check succeeds.
6. Verify the live heartbeat and health email before ending the session.
7. Leave the dated script copies in place until the next scheduled update has
   also succeeded.

If any check fails, stop. The active release remains unchanged, and the saved
scripts provide the rollback path.

## Stage 5: promotion

Merge to `main` only after separate approval and after both displays have been
verified. Then change Athens from its pinned canary SHA to `REF=main`. Moving
or deleting Shallowford's root content is a later migration and is not needed
for multi-site operation.
