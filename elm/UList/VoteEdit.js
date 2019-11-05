var init = Elm.UList.VoteEdit.init;
Elm.UList.VoteEdit.init = function(opt) {
    var app = init(opt);
    app.ports.ulistVoteChanged.subscribe(function(voted) {
        var l = document.getElementById('ulist_public_'+opt.flags.vid);
        l.setAttribute('data-voted', voted?1:'');
        l.classList.toggle('invisible', !((l.getAttribute('data-voted') && !pageVars.voteprivate) || l.getAttribute('data-publabel')))
    });
};