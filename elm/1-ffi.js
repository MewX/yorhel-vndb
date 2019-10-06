window.elmFfi_innerHtml = function(wrap) { // \s -> _VirtualDom_property('innerHTML', _Json_wrap(s))
    return function(s) {
        return {
            $: 'a2',
            n: 'innerHTML',
            o: wrap(s)
        }
    }
};
