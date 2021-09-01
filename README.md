# ff2rss
Script that converts Firefox Bookmarks to RSS feed. You need coreutils, grep, awk, sed, curl and sqlite3. You probably have it.

1. Optionally (but recommend): compile https://github.com/eafer/rdrview
2. Run ff2rss.sh and WAIT. It will build initial rss feed with all your Firefox bookmarks in `~/.local/share/bookmarks.rss`
3. Add to crontab: 
`0 */2 * * * /path/to/ff2rss.sh`
4. And to `~/.config/newsboat/urls` or elsewhere:
`file:///home/$USER/.local/share/bookmarks.rss`  
*where `$USER` is your username*
