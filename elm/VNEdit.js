wrap_elm_init('VNEdit', function(init, opt) {
    var app = init(opt);
    app.ports.ivRefresh.subscribe(function() {
        setTimeout(ivInit, 10);
    });
});
