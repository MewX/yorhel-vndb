var p = document.querySelectorAll('.labelfilters')[0];
if(p) {
    var multi = document.getElementById('form_l_multi');
    var l = document.querySelectorAll('.labelfilters input[name=l]');
    l.forEach(function(el) {
        el.addEventListener('click', function() {
            if(multi.checked)
                return true;
            l.forEach(function(el2) { el2.checked = el2 == el });
        });
    });
}
