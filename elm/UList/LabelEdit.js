var init = Elm.UList.LabelEdit.init;
Elm.UList.LabelEdit.init = function(opt) {
    opt.flags.uid = pageVars.uid;
    opt.flags.labels = pageVars.labels;
    var app = init(opt);
    app.ports.ulistLabelChanged.subscribe(function(pub) {
        var l = document.getElementById('ulist_public_'+opt.flags.vid);
        l.setAttribute('data-publabel', pub?1:'');
        l.classList.toggle('invisible', !((l.getAttribute('data-voted') && !pageVars.voteprivate) || l.getAttribute('data-publabel')))
    });
};
