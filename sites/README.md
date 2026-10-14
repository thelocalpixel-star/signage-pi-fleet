# Site content

Each directory under `sites/` contains only the content required by that
location. A Pi selects its directory with `/etc/default/signage-site` and
downloads these four files directly:

- `index.html`
- `ad.mp4`
- `takeover.html`
- `takeover.png`

Location media must not be duplicated at the repository root. This keeps each
Pi's update small and prevents one location from downloading another location's
ads.

To add a location, create `sites/<site>/` with all four required files. Use a
lowercase site name containing only letters, numbers, and hyphens.
