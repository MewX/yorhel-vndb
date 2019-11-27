var init = Elm.ColSelect.init;
Elm.ColSelect.init = function(opt) {
    opt.flags = [ location.href, opt.flags ];
    return init(opt);
};
