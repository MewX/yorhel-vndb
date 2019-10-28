window.elmFfi_innerHtml = function(wrap,call) { // \s -> _VirtualDom_property('innerHTML', _Json_wrap(s))
    return function(s) {
        return {
            $: 'a2',
            n: 'innerHTML',
            o: wrap(s)
        }
    }
};

window.elmFfi_elemCall = function(wrap,call) { // _Browser_call
    return call
};
