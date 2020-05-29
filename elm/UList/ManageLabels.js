document.querySelectorAll('#managelabels').forEach(function(b) {
    b.onclick = function() {
        document.querySelectorAll('.managelabels').forEach(function(e) { e.classList.toggle('hidden') })
        document.querySelectorAll('.savedefault').forEach(function(e) { e.classList.add('hidden') })
    };
    return false;
});

wrap_elm_init('UList.ManageLabels', function(init, opt) {
    opt.flags = { uid: pageVars.uid, labels: pageVars.labels };
    init(opt);
});
