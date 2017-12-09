# all (default)
#   Same as `make dirs js icons skins robots`
#
# dirs
#   Creates the required directories not present in git
#
# js
#   Generates the Javascript code
#
# icons
#   Generates the CSS icon sprites
#
# skins
#   Generates the CSS code
#
# robots
#   Ensures that www/robots.txt and static/robots.txt exist. Can be modified to
#   suit your needs.
#
# chmod
#   For when the http process is run from a different user than the files are
#   chown'ed to. chmods all files and directories written to from vndb.pl.
#
# chmod-autoupdate
#   As chmod, but also chmods all files that may need to be updated from a
#   normal 'make' run. Should be used when the regen_static option is enabled
#   and the http process is run from a different user.
#
# multi-start, multi-stop, multi-restart:
#   Start/stop/restart the Multi daemon. Provided for convenience, a proper initscript
#   probably makes more sense.
#
# NOTE: This Makefile has only been tested using a recent version of GNU make
#   in a relatively up-to-date Arch/Gentoo Linux environment, and may not work in
#   other environments. Patches to improve the portability are always welcome.


.PHONY: all dirs js icons skins robots chmod chmod-autoupdate multi-stop multi-start multi-restart

all: dirs js skins robots data/config.pl util/sql/editfunc.sql

dirs: static/ch static/f static/cv static/sf static/st data/log www www/feeds www/api

js: static/f/vndb.js

icons: data/icons/icons.css

skins: $(shell ls static/s | sed -e 's/\(.\+\)/static\/s\/\1\/style.css/g')

robots: dirs www/robots.txt static/robots.txt

util/sql/editfunc.sql: util/sqleditfunc.pl util/sql/schema.sql
	util/sqleditfunc.pl

static/ch static/cv static/sf static/st:
	mkdir -p $@;
	for i in $$(seq -w 0 1 99); do mkdir -p "$@/$$i"; done

data/log www www/feeds www/api static/f:
	mkdir -p $@

data/config.pl:
	cp -n data/config_example.pl data/config.pl

static/f/vndb.js: data/js/*.js util/jsgen.pl data/config.pl data/global.pl | static/f
	util/jsgen.pl

data/icons/icons.css: data/icons/*.png data/icons/*/*.png util/spritegen.pl | static/f
	util/spritegen.pl

static/s/%/style.css: static/s/%/conf util/skingen.pl data/style.css data/icons/icons.css
	util/skingen.pl $*

%/robots.txt:
	echo 'User-agent: *' > $@
	echo 'Disallow: /' >> $@

chmod: all
	chmod -R a-x+rwX static/{ch,cv,sf,st}

chmod-autoupdate: chmod
	chmod a+xrw static/f data/icons
	chmod -f a-x+rw static/s/*/{style.css,boxbg.png} static/f/icons.png


# may wait indefinitely, ^C and kill -9 in that case
define multi-stop
	if [ -s data/multi.pid ]; then\
	  kill `cat data/multi.pid`;\
	  while [ -s data/multi.pid ]; do\
	    if kill -0 `cat data/multi.pid`; then sleep 1;\
	    else rm -f data/multi.pid; fi\
	  done;\
	fi
endef

define multi-start
	util/multi.pl
endef

multi-stop:
	$(multi-stop)

multi-start:
	$(multi-start)

multi-restart:
	$(multi-stop)
	$(multi-start)
