#!/bin/bash
set -e

# this example assumes the use of https://github.com/tianon/rawdns
# most importantly, it assumes DNS is on the docker0 bridge (172.17.42.1)

defaultServer='example.com' # explicit first "server { }"

listens=(
	# http://nginx.org/en/docs/http/ngx_http_core_module.html#listen
	80
	'443 ssl http2'
)
resolvers=(
	# http://nginx.org/en/docs/http/ngx_http_core_module.html#resolver
	172.17.42.1
	#8.8.8.8
	#8.8.4.4
)

declare -A redirects=(
	[www.example.com]='example.com'
	[blog.example.com]='example.com'

	[example.net]='example.com'
	[www.example.net]='example.com'
)

declare -A forcedProtos=(
	[example.com]='https'

	[bugzilla.example.com]='https'
	[munin.example.com]='https'
	[public.example.com]='http'
)

declare -A simpleProxies=(
	[example.com]='http://wordpress-example.docker'

	[bugzilla.example.com]='https://bugzilla-example.docker'

	[other.example.com]='http://some-external-host.corp.example.com'
)

declare -A simpleStatics=(
	[public.example.com]='/static/public'
)

declare -A sslCerts=(
	# http://nginx.org/en/docs/http/configuring_https_servers.html#single_http_https_server
	[public.example.com]='/path/to/somecert.pem /path/to/somecert.key'
	[other.example.com]='/path/to/othercert.pem /path/to/othercert.key'
)
