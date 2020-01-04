document.querySelectorAll('#savedefault').forEach(function(b) {
    b.onclick = function() {
        document.querySelectorAll('.savedefault').forEach(function(e) { e.classList.toggle('hidden') })
        document.querySelectorAll('.managelabels').forEach(function(e) { e.classList.add('hidden') })
    };
    return false;
});
