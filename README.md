# Funbox Scripts

<a href="LICENSE.md"><img align="right" alt="GPL-3.0 Logo"
src="https://www.gnu.org/graphics/gplv3-127x51.png">
</a>

These are scripts we use across our servers. Some of these are a lot older than
others, and not all of them are up to our modern coding standards. If it isn't
listed here, it's probably not helpful for you.

### `auth_report.pl`

Shows all attempted and successful ssh logins from `auth.log` files. Helps you
understand what usernames attackers are guessing.

### `better_chown.pl`

Recursively sets permissions, users, and groups for files and directories.
Replaced a ridiculous `find` command we had cronned up.

### `blockips.sh`

Uses `iptables` to completely block all traffic from IPs given in a list. Useful
if you want to block a list of all the IPs for a country.

### `change_container.pl`

Uses `ffmpeg` to convert the given media file into a widely web-compatible
format. The name is legacy. This script started as a way to unpack `mkv` files
into `mp4`, but has evolved into a one-stop-shop for all web video conversions.

### `deluge-status.pl`

Prints whether or not `deluged` is running. Useful as a login status script for
seedboxes that host Linux distros and definitely nothing else.

### `freedns_update.pl`

Updates dynamic DNS from `freedns.afraid.org`. This is useful if you have a cron
job for DNS updates from your server, and want to, say, only get emails if your
IP actually changes.

### `fuzzies.sh`

Defines several Bash functions that use `fzf` for an interactive UI.

### `install_deps.sh`

Uses CPAN to install the Perl libraries needed for our Perl scripts.

NOTE: this installs the libraries for the user who ran the script. If you expect
service users (or root) to run these scripts, you may want to install
dependencies as root (i.e. run this script with `sudo`).

### `merge_subs.pl`

Uses `ffmpeg` to embed subtitles into the given video file. Useful if you want
to set the language code for multiple subtitle files.

### `ping_daemon.pl`

A daemon that will ping the given address and output whether or not it can reach
it. This is useful if you want to generate a timeline of spotty internet
connectivity, particularly if your ISP is trying to lie to you and tell you it's
fine.

### `print-ip-info.py`

Prints your public IP. This is useful as a login script if you expect the target
system to be on a VPN.

### `smartctl_test_monitor.pl`

Prints the status of disk SMART tests being run by `smartctl`. Combine with
`watch` to get status updates over time.

### `sub_to_utf8.sh`

Uses `ffmpeg` to convert a subtitle file to UTF-8 encoding. This is mostly
useful for non-English language subtitles.

### `synapse_login.py`

Generates a Matrix Synapse admin login token. I don't know why this isn't built
into `synctl`, but it's not, so I made it instead.

### `whoistheasshole.pl`

Sums up the CPU usage for each individual user, then names and shames the
winner. Mostly useful on multi-user systems, but can also be useful to identify
when a service user (e.g. postgres) is doing more than you expect.


# Dependencies

Perl scripts should run on any \*nix system (including Mac), but require a few
libraries. You can install these with CPAN using the included `install_deps.sh`
script. If you're running scripts as a service user or as root, you may need to
use `sudo` on this script.

Bash scripts depend on whatever command they're automating. Usually this is
`ffmpeg`. Sometimes it's `fzf`. You don't need these unless you're using the
scripts that need them.

# Installing

Consider cloning this repo, then symlinking the scripts you want into your `bin`
directory. This will allow you fetch updates using git, instead of needing to
manually re-download scripts when they update.

If that sounds like too much work, you can manually download too.

# License

Copyright 2023 [Mimickal](https://github.com/Mimickal)<br/>
This code is licensed under the [GPL-3.0](./LICENSE.md) license.<br/>
These are locally-run scripts, but don't be a dick. If they are useful to you
and you add something, I'd like to integrate it back in for others.
