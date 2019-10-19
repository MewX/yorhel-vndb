document.querySelectorAll('#labeledit').forEach(function(b) {
    b.onclick = function() {
        document.querySelectorAll('.labeledit').forEach(function(e) { e.classList.toggle('hidden') })
    };
    return false;
})
