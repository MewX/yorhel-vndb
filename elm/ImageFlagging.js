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

    app.ports.updateUrl.subscribe(function(id) {
        if(curid == id || !history || !history.replaceState)
            return;
        curid = id;
        var imgid = id.replace(/[\(\),]/g, '');
        history.replaceState(id, "Image flagging for "+imgid, "/img/"+imgid);
    });
};
