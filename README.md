Copy `example/config.sh` to the directory of your choice.  Modify as desired.

When you're ready, run with something like:

```console
$ ./generate.sh /path/to/target/config.sh
$ docker run -d \
	--name nginx \
	-p 80:80 \
	-v /path/to/target:/etc/nginx/conf.d:ro \
	--restart always \
	nginx
$ sleep 1 # to give it a moment to come up
$ docker logs nginx
```
