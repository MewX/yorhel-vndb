var init = Elm.ImageFlagging.init;

Elm.ImageFlagging.init = function(opt) {
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
