#!/bin/sh

RSSPLACE="${XDG_DATA_HOME:-$HOME/.local/share}/bookmarks.rss"

cp "$(ls -1dt ~/.mozilla/firefox/*/ | grep "\..*\." | head -n1)places.sqlite" /tmp/places.sqlite

sql="SELECT moz_bookmarks.lastModified, parent, moz_bookmarks.title, url
         FROM moz_places
         INNER JOIN moz_bookmarks ON moz_places.id=moz_bookmarks.fk
         WHERE type=1"


sedd=$( for i in $(echo "$sql" | sqlite3 /tmp/places.sqlite  | awk -F'|' '{print $2}' | sort -u) ; do
        ( printf "%s" "$i " && sqlite3 /tmp/places.sqlite "SELECT title FROM moz_bookmarks WHERE id=$i" ) | sed 's/^/s|\^/;s/ /\$|/;s/$/|/' 
done )

result=$(echo "$sql" | sqlite3 -separator ';;;'  /tmp/places.sqlite | sed '/getElementsByTagName/d' | sed 's/</(/g;s/>/)/g')

echo '<?xml version="1.0" encoding="utf-8"?>
<?xml-stylesheet type="text/css" href="rss.css" ?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">

  <channel>
    <title>Firefox Bookmarks</title>
    <description>My Firefox bookmarks.</description>
    <language>en-us</language>
    <link>example.org</link>
    <atom:link href="http://localhost/rss.rss" rel="self" type="application/rss+xml" />
' > "$RSSPLACE"

while IFS= read -r line ; do
	time=$(date -d @$(echo "$line" | awk -F';;;' '{print $1}' | cut -b1-10 ) +"%a, %d %b %Y %H:%M:%S %z")
	folder=$(echo "$line" | awk -F';;;' '{print $2}' | sed "$sedd")
	desc=$(echo "$line" | awk -F';;;' '{print $3}')
	url=$(echo "$line" | awk -F';;;' '{print $4}' )
	# printf "%s;;;%s;;;%s;;;%s\n" "$time" "$folder" "$desc" "$url"
	cat << EOF >> "$RSSPLACE"
  <item>
      <title>$desc</title>
      <guid>$url</guid>
      <pubDate>$time</pubDate>
      <description><![CDATA[<p>$desc - $folder</p>]]></description>
    </item>
EOF
done <<< "$result"

echo "  </channel>
</rss>" >> "$RSSPLACE"

rm /tmp/places.sqlite
