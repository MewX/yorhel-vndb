/* Polyfill for classList.toggle() (mainly for IE) */
(function() {
    var historic = DOMTokenList.prototype.toggle;
    DOMTokenList.prototype.toggle = function(token, force) {
        if(arguments.length > 0 && this.contains(token) === force) {
            return force;
        }
        return historic.call(this, token);
    };
})();


/* Polyfill for Element.matches() and Element.closest() */
if(!Element.prototype.matches)
    Element.prototype.matches = Element.prototype.msMatchesSelector || Element.prototype.webkitMatchesSelector;
if(!Element.prototype.closest)
    Element.prototype.closest = function(s) {
        var el = this;
        if(!document.documentElement.contains(el)) return null;
        do {
            if(el.matches(s)) return el;
            el = el.parentElement || el.parentNode;
        } while(el !== null && el.nodeType === 1);
        return null;
    };


function each(arr, cb) {
    Array.prototype.forEach.call(arr, cb);
}


/* Elm FFI, see elm/Lib/Ffi.elm.
 *
 * All functions are passed a reference to _Json_wrap() to wrap Javascript
 * values to values that Elm can work with; that function works differently
 * depending on whether the Elm code was compiled with --optimize.
 */
window.elmFfi_openLightbox = function(wrap) { // _VirtualDom_property('onclick', _Json_wrap(function..))
    return {
        $: 'a2',
        n: 'onclick',
        o: wrap(function() { return window.openLightbox(this) })
    }
};
window.elmFfi_innerHtml = function(wrap) { // \s -> _VirtualDom_property('innerHTML', _Json_wrap(s)
    return function(s) {
        return {
            $: 'a2',
            n: 'innerHTML',
            o: wrap(s)
        }
    }
};
window.elmFfi_curYear = function() { return (new Date()).getFullYear() };


/* Add the X-CSRF-Token header to every POST request. Based on:
 * https://stackoverflow.com/questions/24196140/adding-x-csrf-token-header-globally-to-all-instances-of-xmlhttprequest/24196317#24196317
 */
(function() {
    var open = XMLHttpRequest.prototype.open,
        token = document.querySelector('meta[name=csrf-token]').content;

    XMLHttpRequest.prototype.open = function(method, url) {
        var ret = open.apply(this, arguments);
        this.dataUrl = url;
        if(method.toLowerCase() == 'post' && /^\//.test(url))
            this.setRequestHeader('X-CSRF-Token', token);
        return ret;
    };
})();


/* Find all divs with a data-elm-module, and embed the given Elm module in the div */
each(document.querySelectorAll('div[data-elm-module]'), function(el) {
    var mod = el.getAttribute('data-elm-module').split('.').reduce(function(p, c) { return p[c] }, window.Elm);
    var flags = el.getAttribute('data-elm-flags');
    if(flags)
        mod.init({ node: el, flags: JSON.parse(flags)});
    else
        mod.init({ node: el });
});


/* Navbar toggles */
each(document.querySelectorAll('.navbar__toggler'), function(el) {
    el.onclick = function() {
        el.closest('.navbar').classList.toggle('navbar--expanded');
    };
});
each(document.querySelectorAll('.nav-sidebar__selection'), function(el) {
    el.onclick = function() {
        el.closest('.nav-sidebar').classList.toggle('nav-sidebar--expanded');
    };
});


/* Dropdown menus */
each(document.querySelectorAll('.dropdown'), function(el) {
    var visible = false;

    function cancel() { visible = false; update() }

    function update() {
        el.classList.toggle('dropdown--open', visible);
        setTimeout(function() {
            if(visible)
                document.body.addEventListener('click', cancel);
            else
                document.body.removeEventListener('click', cancel);
        });
    }

    var toggle = el.querySelector('.dropdown__toggle');
    if(toggle)
        toggle.onclick = function() {
            visible = !visible;
            update();
            return false;
        };
});


/* Measure the height of each element within the views and place them in approximately equal columns */
each(document.querySelectorAll('.js-columnize'), function(el) {
    var columns = Number(el.dataset.columns || 2);
    var children = Array.prototype.slice.apply(el.children);
    var colHeight = children.reduce(function(a, n) { return a + n.offsetHeight }, 0) / columns;

    var col;
    var curHeight = 0;
    var row = document.createElement('row');
    row.className = 'row';

    children.forEach(function(child) {
        if(!col) {
            col = document.createElement('div');
            col.className = 'col-lg col-lg--1';
            row.appendChild(col);
        }
        curHeight += child.offsetHeight;
        col.appendChild(child);
        if(curHeight >= colHeight) {
            col = null;
            curHeight = 0;
        }
    });
    el.appendChild(row);
});


/* Ensure VN sidebar doesn't overlap header area */
(function() {
    var raisedTop = document.querySelector('.raised-top');
    var sidebar = document.querySelector('.vn-page__top-details');
    if (!raisedTop || !sidebar) return;

    var img = sidebar.querySelector('.vn-img-desktop');
    var nextEl = img && img.nextElementSibling;
    if (!img || !nextEl) return;

    function addMargin() {
        // reset margin bottom, otherwise if we're called more than once, otherwise the numbers will be off
        img.style.marginBottom = '25px';
        // 29: default margin of img (25px) + .top-bar (4px)
        if (sidebar.offsetTop + nextEl.offsetTop < raisedTop.offsetHeight + 29) {
            img.style.marginBottom = (raisedTop.offsetHeight - (sidebar.offsetTop + img.offsetTop + img.offsetHeight) + 29) + 'px';
        }
    }

    addMargin();
    if (!img.complete) {
        img.addEventListener('load', addMargin);
    }
    window.addEventListener('resize', function() {
        setTimeout(addMargin, 0);
    });
})();


/* NSFW Image toggle */
each(document.querySelectorAll('img[data-toggle-img]'), function(el) {
    el.onclick = function() {
        var cur = this.src;
        this.src = this.getAttribute('data-toggle-img');
        this.setAttribute('data-toggle-img', cur);
        return false;
    };
});


/* VN tag collapsing, category toggles & spoiler level */
(function() {
    var tags = document.querySelector('.tag-summary__tags');
    if(!tags)
        return;

    var collapsed = true;
    var show_all = document.querySelector('.tag-summary__show-all');
    var check_collapsable = function() {
        show_all.classList.toggle('d-none', tags.scrollHeight <= 50);
    };
    check_collapsable();

    show_all.onclick = function() {
        collapsed = !collapsed;
        tags.classList.toggle('tag-summary--collapsed', collapsed);
        show_all.querySelector('.caret').classList.toggle('caret--up', !collapsed);
        return false;
    };

    var toggle = function(cat) {
        var sw = document.querySelector('.tag-summary__option--'+cat);
        sw.onclick = function() {
            sw.classList.toggle('switch--on');
            tags.classList.toggle('tag-summary--hide-'+cat);
            check_collapsable();
            return false;
        };
    };
    toggle('cont');
    toggle('ero');
    toggle('tech');

    var spoil_label = document.querySelector('.tag-summary_option--spoil');
    var spoil = function(lvl) {
        var lnk = document.querySelector('.tag-summary_option--spoil-'+lvl);
        lnk.onclick = function() {
            spoil_label.innerHTML = lnk.innerHTML;
            tags.classList.toggle('tag-summary--hide-spoil-1', lvl < 1);
            tags.classList.toggle('tag-summary--hide-spoil-2', lvl < 2);
            check_collapsable();
            return false;
        };
    };
    spoil(0);
    spoil(1);
    spoil(2);
})();


/* Char page spoiler level and sexual trait hiding */
(function() {
    var ero = document.querySelector('.page-inner-controls__option-ero');
    if(!ero)
        return;

    var main = document.querySelector('.main-container');

    ero.onclick = function() {
        var on = main.classList.contains('charpage--hide-ero');
        main.classList.toggle('charpage--hide-ero', !on);
        ero.classList.toggle('switch--on', on);
        return false;
    };

    var spoil_label = document.querySelector('.page-inner-controls__option-spoil');
    var spoil = function(lvl) {
        var lnk = document.querySelector('.page-inner-controls__option-spoil-'+lvl);
        lnk.onclick = function() {
            spoil_label.innerHTML = lnk.innerHTML;
            main.classList.toggle('charpage--hide-spoil-1', lvl < 1);
            main.classList.toggle('charpage--hide-spoil-2', lvl < 2);
            return false;
        };
    };
    spoil(0);
    spoil(1);
    spoil(2);
})();


/* Lightbox driver.
 * Usage:
 *
 *    <a href="dest-image" onclick="return openLightbox(this)" data-lightbox-id="x" data-lightbox-nfo="json">..</a>
 *
 *  Similar links with the same id are grouped. nfo should be a JSON object
 *  that matches the "Image" type in Lightbox.elm. "full", "thumb" and "load"
 *  are inferred if not present.
 */
(function(){
    var div;
    var app;
    var preload = {};

    var create = function() {
        if(div)
            return;

        div = document.createElement('div');
        document.body.appendChild(div);
        app = window.Elm.Lightbox.init({ node: div });

        app.ports.close.subscribe(function() {
            document.body.classList.remove('lightbox-open');
        });

        app.ports.preload.subscribe(function(url) {
            if(!preload[url]) {
                preload[url] = new Image();
                preload[url].onload = function() { app.ports.preloaded.send(url); };
                preload[url].src = url;
            }
            if(preload[url].complete)
                preload[url].onload();
        });
    };

    var model = function(ev) {
        var l = document.querySelectorAll("a[data-lightbox-id="+ev.getAttribute('data-lightbox-id')+"]");
        var mod = { width: 0, height: 0, images: [], current: 0 };
        for(var i=0; i<l.length; i++) {
            if(l[i] == ev)
                mod.current = i;
            var inf = JSON.parse(l[i].getAttribute('data-lightbox-nfo'));
            if(!inf.full)  inf.full  = l[i].href;
            if(!inf.thumb) inf.thumb = inf.full.replace("/sf/", "/st/");
            if(!inf.rel)   inf.rel   = null;
            inf.load = !!preload[inf.full];
            mod.images.push(inf);
        }
        return mod;
    };

    window.openLightbox = function(ev) {
        create();
        document.body.classList.add('lightbox-open');
        app.ports.open.send(model(ev));
        return false;
    };
})();


/* VN Gallery NSFW toggle */
(function(){
    var gallery = document.querySelector('.gallery');
    if(!gallery)
        return;

    var show_nsfw = gallery.classList.contains('gallery--show-r18');
    var toggle = gallery.querySelector('.gallery-r18-toggle');
    if(toggle)
        toggle.onclick = function() {
            show_nsfw = !show_nsfw;
            toggle.classList.toggle('switch--on', show_nsfw);
            gallery.classList.toggle('gallery--show-r18', show_nsfw);
            return false;
        };

    var images = gallery.querySelectorAll('.gallery__image-link');
    each(images, function(el) {
        el.onclick = function() {
            // Fixup data-lightbox-id to exclude hidden images before opening the lightbox
            each(images, function(img) {
                img.setAttribute('data-lightbox-id', !show_nsfw && img.classList.contains('gallery__image--r18') ? 'scr-nsfw' : 'scr');
            });
            return openLightbox(this);
        };
    });
})();


/* VN character switcher.
 * TODO: Update URL on switch?
 */
(function(){
    var chars = document.querySelectorAll('#characters .character');
    if(!chars)
        return;
    var links = document.querySelectorAll('.character-browser__top-items .character-browser__char');

    each(links, function(el) {
        el.onclick = function() {
            var id = el.getAttribute('data-character');
            each(chars, function(ch) { ch.classList.toggle('d-none', ch.getAttribute('data-character') != id); });
            each(links, function(lk) { lk.classList.toggle('character-browser__char--active', el == lk); });
            return false;
        };
    });
})();


/* User VN List */
(function(){
    function toggleExpand(el, contentClass) {
        var arrow = el.querySelector('.expand-arrow');
        arrow.classList.toggle('expand-arrow--open');

        var nextRow = el.closest('tr').nextSibling;
        while (nextRow) {
            // skip over text nodes
            while (nextRow && nextRow.nodeType == Node.TEXT_NODE) {
                nextRow = nextRow.nextSibling;
            }
            if (nextRow) {
                if (nextRow.classList.contains(contentClass)) {
                    // is this the row we're looking for?
                    nextRow.classList.toggle('d-none');
                    break;
                }
                // apparently not, so continue to next
                nextRow = nextRow.nextSibling;
            }
        }
    }

    each(document.querySelectorAll('.vn-list .vn-list__expand-releases'), function(el) {
        el.addEventListener('click', function() {
            toggleExpand(el, 'vn-list__releases-row');
        });
    });

    each(document.querySelectorAll('.vn-list .vn-list__expand-comment'), function(el) {
        el.addEventListener('click', function() {
            toggleExpand(el, 'vn-list__comment-row');
        });
    });
})();
