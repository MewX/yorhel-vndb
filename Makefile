# all (default)
#   Create all the necessary directories, javascript, css, etc.
#
# prod
#   Create static assets for production. Requires the following additional dependencies:
#   - CSS::Minifier::XS
#   - uglifyjs
#   - zopfli
#
# chmod
#   For when the http process is run from a different user than the files are
#   chown'ed to. chmods all files and directories written to from vndb.pl.
#
# multi-start, multi-stop, multi-restart:
#   Start/stop/restart the Multi daemon. Provided for convenience, a proper initscript
#   probably makes more sense.
#
# NOTE: This Makefile has only been tested using a recent version of GNU make
#   in a relatively up-to-date Arch/Gentoo Linux environment, and may not work in
#   other environments. Patches to improve the portability are always welcome.


.PHONY: all prod chmod multi-stop multi-start multi-restart

ALL_KEEP=\
	static/ch static/cv static/sf static/st \
	data/log static/f static/v3 www www/feeds www/api \
	data/conf.pl \
	www/robots.txt static/robots.txt

ALL_CLEAN=\
	static/f/vndb.js \
	static/f/v2rw.js \
	data/icons/icons.css \
	static/v3/elm.js \
	static/v3/style.css \
	util/sql/editfunc.sql \
	$(shell ls static/s | sed -e 's/\(.\+\)/static\/s\/\1\/style.css/g')

PROD=\
	static/v3/elm-opt.js \
	static/v3/min.js static/v3/min.js.gz \
	static/v3/min.css static/v3/min.css.gz \
	static/f/vndb.min.js static/f/vndb.min.js.gz \
	static/f/v2rw.min.js static/f/v2rw.min.js.gz \
	static/f/icons.opt.png \
	$(shell ls static/s | sed -e 's/\(.\+\)/static\/s\/\1\/style.min.css/g') \
	$(shell ls static/s | sed -e 's/\(.\+\)/static\/s\/\1\/style.min.css.gz/g')

all: ${ALL_KEEP} ${ALL_CLEAN}
prod: all ${PROD}

clean:
	rm -f ${ALL_CLEAN} ${PROD}
	rm -f static/f/icons.png
	rm -f elm3/Lib/Gen.elm
	rm -rf elm/elm-stuff/build-artifacts
	rm -rf elm3/elm-stuff/build-artifacts

cleaner: clean
	rm -rf elm/elm-stuff
	rm -rf elm3/elm-stuff

util/sql/editfunc.sql: util/sqleditfunc.pl util/sql/schema.sql
	util/sqleditfunc.pl

static/ch static/cv static/sf static/st:
	mkdir -p $@;
	for i in $$(seq -w 0 1 99); do mkdir -p "$@/$$i"; done

data/log www www/feeds www/api static/f static/v3:
	mkdir -p $@

data/conf.pl:
	cp -n data/conf_example.pl data/conf.pl

%/robots.txt: | www
	echo 'User-agent: *' > $@
	echo 'Disallow: /' >> $@

%.gz: %
	zopfli $<

chmod: all
	chmod -R a-x+rwX static/{ch,cv,sf,st}



# v2 & v2-rw

data/icons/icons.css static/f/icons.png: data/icons/*.png data/icons/*/*.png util/spritegen.pl | static/f
	util/spritegen.pl
static/f/icons.png: data/icons/icons.css

static/f/icons.opt.png: static/f/icons.png
	zopflipng -m --lossy_transparent $< $@

static/s/%/style.css: static/s/%/conf util/skingen.pl data/style.css data/icons/icons.css
	util/skingen.pl $*

static/s/%/style.min.css: static/s/%/style.css
	perl -MCSS::Minifier::XS -e 'undef $$/; print CSS::Minifier::XS::minify(scalar <>)' <$< >$@



# v2

static/f/vndb.js: data/js/*.js lib/VNDB/Types.pm util/jsgen.pl data/conf.pl | static/f
	util/jsgen.pl

static/f/vndb.min.js: static/f/vndb.js
	uglifyjs $< --compress --mangle -o $@



# v2-rw

define cat-js
	sed -i 's/var author\$$project\$$Lib\$$Ffi\$$/var __unused__/g' $@
	sed -Ei 's/author\$$project\$$Lib\$$Ffi\$$([a-zA-Z0-9_]+)/window.elmFfi_\1(_Json_wrap)/g' $@
	for fn in elm/*.js elm/*/*.js; do \
		echo "(function(){'use strict';"; \
		cat $$fn; \
		echo "})();"; \
	done >>$@
endef

elm/Gen/.generated: lib/VNWeb/*.pm lib/VNWeb/*/*.pm lib/VNDB/Types.pm lib/VNDB/Config.pm data/conf.pl
	util/vndb.pl elmgen

static/f/v2rw.js: elm/*.elm elm/*/*.elm elm/*.js elm/*/*.js elm/Gen/.generated | static/f
	cd elm && ELM_HOME=elm-stuff elm make *.elm */*.elm --output ../$@
	${cat-js}

static/f/v2rw.min.js: elm/*.elm elm/*/*.elm elm/*.js elm/*/*.js elm/Gen/.generated | static/f
	cd elm && ELM_HOME=elm-stuff elm make --optimize *.elm --output ../$@
	${cat-js}
	uglifyjs $@ --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle -o $@~
	mv $@~ $@



# v3

elm3/Lib/Gen.elm: lib/VN3/*.pm lib/VN3/*/*.pm data/conf.pl
	util/vndb3.pl elmgen >$@

static/v3/elm.js: elm3/*.elm elm3/*/*.elm elm3/Lib/Gen.elm
	cd elm3 && ELM_HOME=elm-stuff elm make *.elm */*.elm --output ../$@
	sed -i 's/var author\$$project\$$Lib\$$Ffi\$$/var __unused__/g' $@
	sed -Ei 's/author\$$project\$$Lib\$$Ffi\$$([a-zA-Z0-9_]+)/window.elmFfi_\1(_Json_wrap)/g' $@

static/v3/elm-opt.js: elm3/*.elm elm3/*/*.elm elm3/Lib/Gen.elm
	cd elm3 && ELM_HOME=elm-stuff elm make --optimize *.elm */*.elm --output ../$@
	sed -i 's/var author\$$project\$$Lib\$$Ffi\$$/var __unused__/g' $@
	sed -Ei 's/author\$$project\$$Lib\$$Ffi\$$([a-zA-Z0-9_]+)/window.elmFfi_\1(_Json_wrap)/g' $@

static/v3/min.js: static/v3/elm-opt.js static/v3/vndb.js
	uglifyjs $^ --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle -o $@


CSS=\
	css3/framework/base.css\
	css3/framework/helpers.css\
	css3/framework/grid.css\
	css3/framework/elements.css\
	css3/vndb.css

static/v3/style.css: ${CSS} | static/f
	cat $^ >$@

static/v3/min.css: static/v3/style.css
	perl -MCSS::Minifier::XS -e 'undef $$/; print CSS::Minifier::XS::minify(scalar <>)' <$< >$@



# Multi

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
