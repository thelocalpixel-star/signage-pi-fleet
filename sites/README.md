# Site content

Each directory under `sites/` contains only the content required by that
location. A Pi selects its directory with `/etc/default/signage-site` and
downloads these four files directly:

- `index.html`
- `ad.mp4`
- `takeover.html`
- `takeover.png`

Shallowford's former root files remain temporarily during its remote migration.
They can be removed only after the installed updater has successfully validated
and activated `sites/shallowford`.

To add a location, create `sites/<site>/` with all four required files. Use a
lowercase site name containing only letters, numbers, and hyphens.
