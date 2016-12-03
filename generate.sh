#!/bin/bash
set -e

# usage: $0 path/to/config.sh [target/path/]

# default config
defaultServer='example.com'
declare -a listens=( 80 ) resolvers=()
declare -A redirects=() forcedProtos=() simpleProxies=() simpleStatics=() sslCerts=() extraConfigs=()

config="$(dirname "$BASH_SOURCE")/config.sh"
if [ "$1" ]; then
	config="$1"
fi
targetDir="$(dirname "$config")"
if [ "$2" ]; then
	targetDir="$2"
fi
echo "Loading $config ..."
source "$config"
target="$targetDir/default.conf"

declare -A allHostsA=()
for serverName in "${!redirects[@]}" "${!forcedProtos[@]}" "${!simpleProxies[@]}" "${!simpleStatics[@]}" "${!sslCerts[@]}"; do
	allHostsA[$serverName]=1
done
unset allHostsA[$defaultServer]
allHosts=( "$defaultServer" "${!allHostsA[@]}" )

echo "Generating into $target ..."
cat > "$target" <<EOH
# GENERATED BY $BASH_SOURCE via $config - DO NOT MODIFY DIRECTLY

EOH

for resolver in "${resolvers[@]}"; do
	echo "resolver $resolver;" >> "$target"
done

for serverName in "${allHosts[@]}"; do
	sslCert="${sslCerts[$serverName]}"
	redirectTo="${redirects[$serverName]}"
	doForceProto="${forcedProtos[$serverName]}"
	proxyTo="${simpleProxies[$serverName]}"
	staticFiles="${simpleStatics[$serverName]}"
	extraConfig="${extraConfigs[$serverName]}"
	cat >> "$target" <<EOB

server {
EOB
	for listen in "${listens[@]}"; do
		if [[ "$listen" == *ssl* ]]; then
			# ignore "ssl" enabled listen directives unless we have corresponding SSL configuration
			# otherwise, we get:
			#   [error] 6#6: *13 no "ssl_certificate" is defined in server listening on SSL port while SSL handshaking, client: x.x.x.x, server: 0.0.0.0:443
			if [ -z "$sslCert" ]; then
				continue
			fi
		fi
		cat >> "$target" <<EOB
	listen $listen;
EOB
	done
	if [ "$sslCert" ]; then
		ssl=( $sslCert ) # split on whitespace
		cert="${ssl[0]}"
		key="${ssl[1]}"
		cat >> "$target" <<EOB

	ssl_certificate $cert;
	ssl_certificate_key $key;
	include conf.d/ssl.include;
EOB
	fi
	cat >> "$target" <<EOB

	server_name $serverName;
	include conf.d/set-proto.include;

	location / {
		# start a default "location" block to allow for "add_header", etc.
EOB
	if [ "$doForceProto" ]; then
		cat >> "$target" <<EOB

		set \$force_proto "$doForceProto";
		include conf.d/force-proto.include;
EOB
	fi

	if [ "$redirectTo" ]; then
		redirectTo='$proto://'"$redirectTo"'$request_uri' # TODO decide if this should support "$redirectTo" already having '$' in it somewhere, and thus not doing this prepend/append
		cat >> "$target" <<EOB

		return 301 $redirectTo;
EOB
	fi

	if [ "$staticFiles" ]; then
		cat >> "$target" <<EOB

		root $staticFiles;
		index index.html index.htm index;
		try_files \$uri \$uri/ \$uri.html =404;
		add_header Cache-Control "public";
EOB
	fi

	if [ "$proxyTo" ]; then
		cat >> "$target" <<EOB

		# let the proxied server handle whether this "body" is too large
		client_max_body_size 0;

		proxy_pass $proxyTo;
		include conf.d/proxy-pass.include;
EOB
	fi
	cat >> "$target" <<EOB
	}
EOB
	if [ "$extraConfig" ]; then
		extraConfig="${extraConfig#$'\n'}"
		extraConfig="${extraConfig%$'\n'}"
		{
			echo
			echo "$extraConfig"
		} >> "$target"
	fi
	cat >> "$target" <<EOB
}
EOB
done

echo "Copying *.include to $targetDir/"
cp -v "$(dirname "$BASH_SOURCE")"/*.include "$targetDir"
