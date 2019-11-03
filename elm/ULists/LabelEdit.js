var init = Elm.ULists.LabelEdit.init;
Elm.ULists.LabelEdit.init = function(opt) {
    opt.flags.uid = pageVars.uid;
    opt.flags.labels = pageVars.labels;
    init(opt);
};
