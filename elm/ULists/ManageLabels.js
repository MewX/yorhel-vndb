document.querySelectorAll('#managelabels').forEach(function(b) {
    b.onclick = function() {
        document.querySelectorAll('.managelabels').forEach(function(e) { e.classList.toggle('hidden') })
    };
    return false;
})
