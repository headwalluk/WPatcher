# WPatcher

A tool for patching and unpatching WordPress plugins and themes.

**IMPORTANT** This is an active work-in-progress. DO NOT USE THIS TOOL OR ANY OF THE PATCHES YET.

## Quick start

### Install command-line tools

Make sure you've got a working version of [wp-cli](https://github.com/wp-cli/wp-cli)

```bash
# Debian / Ubuntu / Mint / etc...
sudo apt install patch tar ncurses-bin wget
```

### Install / update the tool
```bash
wget -O wpatch "raw.githubusercontent.com/headwalluk/wpatcher/refs/heads/main/wpatch.sh"
chmod +x ./wpatch
sudo mv ./wpatch /usr/local/bin/
```

### Check it works
```bash
wpatch -h
```

## Contents

1. wpatch.sh : A tool to "patch" and "unpatch" plugins and themes in WordPress sites. Patches are stored as diffs and applied with the "patch" command in this script. Original/unpatched versions of the plugins and themes are saved in a local cache so the patches can be reverted.
2. wpatches/ : A collection of ready-to-go patches for some common plugins.

## Background

...


