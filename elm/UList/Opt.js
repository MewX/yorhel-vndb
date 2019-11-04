var init = Elm.UList.Opt.init;
Elm.UList.Opt.init = function(opt) {
    // TODO: This module is more often than not hidden from the page, lazily loading it could improve page load time.
    var app = init(opt);

    app.ports.ulistVNDeleted.subscribe(function(b) {
        var e = document.getElementById('ulist_tr_'+opt.flags.vid);
        e.parentNode.removeChild(e.nextElementSibling);
        e.parentNode.removeChild(e);

        // Have to restripe after deletion :(
        var rows = document.querySelectorAll('.ulist > table > tbody > tr');
        for(var i=0; i<rows.length; i++)
            rows[i].classList.toggle('odd', Math.floor(i/2) % 2 == 0);
    });
};
