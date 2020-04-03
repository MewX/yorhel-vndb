var init = Elm.ImageFlagging.init;

Elm.ImageFlagging.init = function(opt) {
    opt.flags.pWidth  = window.innerWidth  || document.documentElement.clientWidth  || document.body.clientWidth;
    opt.flags.pHeight = window.innerHeight || document.documentElement.clientHeight || document.body.clientHeight;
    var app = init(opt);
    var preload = {};
    var curid = '';

    app.ports.preload.subscribe(function(url) {
        if(Object.keys(preload).length > 100)
            preload = {};
        if(!preload[url]) {
            preload[url] = new Image();
            preload[url].src = url;
        }
    });
};
