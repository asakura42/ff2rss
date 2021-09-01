#!/bin/sh

RSSPLACE="${XDG_DATA_HOME:-$HOME/.local/share}/bookmarks.rss"

curld () { 
	curl -L --connect-timeout 20 --max-time 10 --retry 5 \
  --retry-delay 0 --retry-max-time 40 \
  --compressed --keepalive --tlsv1.2 \
  -A 'Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Accept-Encoding: gzip, deflate' \
  -H 'Connection: keep-alive' \
  -H 'Upgrade-Insecure-Requests: 1' "$@"
}

cp "$(ls -1dt ~/.mozilla/firefox/*/ | grep "\..*\." | head -n1)places.sqlite" /tmp/places.sqlite

sql="SELECT moz_bookmarks.lastModified, parent, moz_bookmarks.title, url
         FROM moz_places
         INNER JOIN moz_bookmarks ON moz_places.id=moz_bookmarks.fk
         WHERE type=1"


sedd=$( for i in $(echo "$sql" | sqlite3 /tmp/places.sqlite  | awk -F'|' '{print $2}' | sort -u) ; do
        ( printf "%s" "$i " && sqlite3 /tmp/places.sqlite "SELECT title FROM moz_bookmarks WHERE id=$i" ) | sed 's/^/s|\^/;s/ /\$|/;s/$/|/' 
done )

result=$(echo "$sql" | sqlite3 -separator ';;;'  /tmp/places.sqlite | sed '/getElementsByTagName/d' | sed 's/</(/g;s/>/)/g')

if [[ $(head -n1 "$RSSPLACE") == '<?xml version="1.0" encoding="utf-8"?>' ]] ; then
	rsse=1
	true
else
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
fi

while IFS= read -r line ; do
	url=$(echo "$line" | awk -F';;;' '{print $4}' )
	desc=$(echo "$line" | awk -F';;;' '{print $3}')
	if grep -a -A2 "<guid>$url</guid>" "$RSSPLACE" | tail -n1 | grep -q -a '<!-- PARSED -->' ; then
		continue
	else
		if curld -sI "$url" | grep -A100 "HTTP.*200" | grep -i "^Content-Type:" | grep -q "htm" ; then
			if command -v rdrview >/dev/null ; then
				page=$(rdrview -H "$url" | tr -d '\n'| sed 's/[[:blank:]]\+/ /g;s/^/<!-- PARSED -->/;s/\[/(/g;s/\]/)/g' | awk '{print substr($0,1,3000);exit}')
			else
				page=$(curld -Ls "$url" | sed 's/<br[^>]*>\s*<br[^>]*>/<p>/g;s/<\/?font[^>]*>//g;s/style="[^"]*"//;s/<\/?span[^>]*>//;s/<style[^>]*>/<style media="aural">/g' | tr -d '\n' | sed 's/<[^\/][^<>]*> *<\/[^<>]*>//g;s/<[^\/][^<>]*><\/[^<>]*>//g;s/[[:blank:]]\+/ /g' |  perl -0777 -pe 's/<script.*?script>//gs' | perl -0777 -pe 's/<ul.*?ul>//gs' | sed 's/^/<!-- PARSED -->/;s/\[/(/g;s/\]/)/g' | awk '{print substr($0,1,3000);exit}')
			fi
		else
			page=""'<!-- PARSED -->'"$desc"
		fi
		if [[ "$page" == '<!-- PARSED -->' ]] ; then
			page=""'<!-- PARSED -->'"$desc"
		fi
		if [ -z "$page" ] ; then
			page=""'<!-- PARSED -->'"$desc"
		fi

	fi
	time=$(date -d @$(echo "$line" | awk -F';;;' '{print $1}' | cut -b1-10 ) +"%a, %d %b %Y %H:%M:%S %z")
	folder=$(echo "$line" | awk -F';;;' '{print $2}' | sed "$sedd")
	
	# printf "%s;;;%s;;;%s;;;%s\n" "$time" "$folder" "$desc" "$url"
	cat << EOF >> "$RSSPLACE"
  <item>
      <title>$desc</title>
      <guid>$url</guid>
      <pubDate>$time</pubDate>
      <description><![CDATA[$page<br><br>$folder]]></description>
    </item>
EOF
done <<< "$result"

sed -i '/^<\/channel>$/d' "$RSSPLACE"
sed -i '/^<\/rss>$/d' "$RSSPLACE"
echo "</channel>
</rss>" >> "$RSSPLACE"


rm /tmp/places.sqlite
