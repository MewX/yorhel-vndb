document.querySelectorAll('#managelabels').forEach(function(b) {
    b.onclick = function() {
        document.querySelectorAll('.managelabels').forEach(function(e) { e.classList.toggle('hidden') })
    };
    return false;
});

var init = Elm.ULists.ManageLabels.init;
Elm.ULists.ManageLabels.init = function(opt) {
    opt.flags = { uid: pageVars.uid, labels: pageVars.labels };
    init(opt);
};
