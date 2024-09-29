# WPatcher

A tool for patching and unpatching WordPress plugins and themes.

**IMPORTANT** This is an active work-in-progress. DO NOT USE THIS TOOL OR ANY OF THE PATCHES YET.

## Quick start

### Install command-line tools

Make sure you've got a working version of [wp-cli](https://github.com/wp-cli/wp-cli)

Install some prerequisites...

```bash
# Debian / Ubuntu / Mint / etc...
sudo apt install patch tar ncurses-bin wget
```


### Install / update the tool
```bash
# Pull the installer script and execute it.
# NOTE: The script installs the tool to /usr/local/bin/wpatch
source <(curl -s https://raw.githubusercontent.com/headwalluk/wpatcher/refs/heads/main/install-wpatcher.sh)

# Update definitions (if you're not using your own local wpatches dir)
wpatch update

# Check it works
wpatch -h
```

Backup your site's plugins

```bash
wpatch -p /var/wexample.com/htdocs backup
```

WPatcher usses ${HOME}/.wpatcher/ as its work directory and local repository. If you use the "backup" command to backup all your site's plugins & themes, the are stored in here.

If you decide to delete ${HOME}/.wpatcher/ for any reason, you might consider having a look in ${HOME}/.wpatcher/repos/ before you do so.


## Examples

Patch all plugins that can be patched

```bash
wpatch --path /var/www/example.com/htdocs patch
```

Patch a single plugin

```bash
wpatch --path /var/www/example.com/htdocs --component woocommerce patch
```

Revert all patches

```bash
wpatch --path /var/www/example.com/htdocs unpatch
```

Use your own local collection of patches

Create a file system like this:

* /opt/my-wp-patches/
 * themes/
 * plugins/
  * my-plugin/
   * my-plugin-1.0.0.patch
  * woocommerce/
   * woocommerce-9.3.2.patch
   * woocommerce-9.3.3.patch

```bash
# Backup all your plugins to your local repository
wpatch --path /var/www/my-website.com/htdocs backup

# Apply all patches from your patches dir that are applicable to this site.
wpatch -d /opt/my-wp-patches/ --path /var/www/my-website.com/htdocs patch

## Unpatch everything.
wpatch -d /opt/my-wp-patches/ --path /var/www/my-website.com/htdocs unpatch
```
