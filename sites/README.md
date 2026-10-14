# Site content

Each directory under `sites/` contains only the content required by that
location. A Pi selects its directory with `/etc/default/signage-site` and
downloads these four files directly:

- `index.html`
- `ad.mp4`
- `takeover.html`
- `takeover.png`

The existing Shallowford files intentionally remain at the repository root
until its installed updater has been migrated and verified remotely. Do not
move or remove those root files as part of adding another site.

To add a location, create `sites/<site>/` with all four required files. Use a
lowercase site name containing only letters, numbers, and hyphens.
