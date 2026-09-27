# Kiwix Offline Library: Home Network Setup

This kit turns the Linux Mint OptiPlex into an offline library server. Any laptop, tablet or phone on the home Wi-Fi can open it in a browser. It includes a kid-friendly encyclopedia and programming references, and nothing on it needs the internet once the files are downloaded.

```
 Kids' laptops / tablets ──Wi-Fi──► Router ──► OptiPlex (Linux Mint)
                                               └─ Docker: kiwix-serve :8080
                                                  └─ /srv/kiwix/zim/*.zim
```

## What gets installed

| Pack | File prefix | Approx. size |
|---|---|---|
| Simple English Wikipedia (with images) | `wikipedia_en_simple_all_maxi` | ~3 GB |
| Vikidia (encyclopedia for ages 8–13) | `vikidia_en_all_maxi` | < 1 GB |
| DevDocs: JavaScript, HTML, CSS, Python | `devdocs_en_*` | < 100 MB each |

Plan for about **5 GB** of disk space, plus room for extras.

## 1. Prepare the OptiPlex (5 minutes)

1. **Give it a fixed address.** In your router's admin page, find *DHCP reservation* (sometimes called *static lease*) and reserve an IP for the OptiPlex. Without this, the address can change and the kids' bookmarks will break.
2. **Copy this folder** to the OptiPlex, for example to `~/kiwix-server`.

## 2. Install (one command)

```bash
cd ~/kiwix-server
sudo ./install.sh
```

The script:

1. Installs Docker, Docker Compose and Avahi (so the machine can be reached by name).
2. Copies the kit to `/opt/kiwix` and creates `/srv/kiwix/zim`.
3. Downloads the newest version of every pack in `zims.conf`, checking its SHA-256 checksum when Kiwix publishes one.
4. Starts the `kiwix` container, set to restart on boot.
5. Sets up a monthly timer that refreshes the content and deletes older versions.
6. Opens port 8080 to the local network if `ufw` is turned on.

When it finishes, it prints the address to use, for example:

```
http://192.168.1.50:8080
http://optiplex.local:8080
```

## 3. Set up the kids' devices

- Open the address in a browser and **bookmark it**, or set it as the home page.
- On the Kiwix home page, each pack appears as a tile. The search box searches inside the open pack.
- `.local` names work on Windows 10/11, macOS, iOS and Linux. On Android and Chromebooks, use the IP address.

## Everyday tasks

| Task | Command |
|---|---|
| Add or remove a pack | `sudo nano /opt/kiwix/zims.conf` then `sudo /opt/kiwix/update-zims.sh` |
| Find exact pack names | `/opt/kiwix/update-zims.sh --search devdocs` (or `phet`, `freecodecamp`, `wikibooks`) |
| Preview an update | `/opt/kiwix/update-zims.sh --dry-run` |
| Update now | `sudo /opt/kiwix/update-zims.sh` |
| Check the server | `docker ps` and `docker logs kiwix` |
| Next auto-update | `systemctl list-timers kiwix-update.timer` |
| Stop / start | `cd /opt/kiwix && docker compose down` / `docker compose up -d` |

In `zims.conf`, each line is a folder on download.kiwix.org and a file prefix *without the date*. The script always picks the newest dated release, so you never have to edit version numbers.

## Good add-ons for kids and coding

These are already listed, commented out, in `zims.conf`. Remove the `#` to turn one on:

- **PhET** (`phet_en_all`): interactive science and math simulations that run offline.
- **Wikibooks** (`wikibooks_en_all_nopic`): open textbooks, including programming ones.
- **Wiktionary** (`wiktionary_en_all_nopic`): a dictionary.
- **freeCodeCamp**: run `--search freecodecamp` first to see the current file names, then add the one you want.
- More DevDocs sets: `devdocs_en_node`, `devdocs_en_git`, and others. Run `--search devdocs` for the full list.

You can browse everything that's available at <https://library.kiwix.org>.

## Notes on child safety

- Simple English Wikipedia and Vikidia are written for younger readers. The full English Wikipedia covers adult topics, so it's left out on purpose.
- Kiwix is read-only, with no accounts, ads or chat. Browsing stays inside the packs you chose, although links to outside websites still work if the device itself has internet access.
- Docker publishes port 8080 directly, which means `ufw` rules don't restrict it. Keep the OptiPlex behind your home router and don't forward port 8080 to the internet.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `docker: permission denied` | Log out and back in (the installer added you to the `docker` group), or use `sudo`. |
| A pack shows `WARN: No file matching…` | The prefix changed upstream. Run `--search <folder>` and update the line in `zims.conf`. |
| The page won't load from another device | On the OptiPlex, check that `curl -I localhost:8080` works. Then check the IP address and that both devices are on the same Wi-Fi (not a guest network). |
| Disk is filling up | Run `du -sh /srv/kiwix/zim/*` and comment out the big packs. The next update removes their old versions only, so delete unwanted files by hand. |
