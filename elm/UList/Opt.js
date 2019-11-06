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

    app.ports.ulistNotesChanged.subscribe(function(n) {
        document.getElementById('ulist_notes_'+opt.flags.vid).innerText = n;
        document.getElementById('ulist_noteflag_'+opt.flags.vid).classList.toggle('blurred', n.length == 0);
    });

    app.ports.ulistRelChanged.subscribe(function(rels) {
        var e = document.getElementById('ulist_relsum_'+opt.flags.vid);
        e.classList.toggle('todo', rels[0] != rels[1]);
        e.classList.toggle('done', rels[1] > 0 && rels[0] == rels[1]);
        e.innerText = rels[0] + '/' + rels[1];
    });
};
