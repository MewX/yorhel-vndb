//order:0 - Before anything else that may use window.pageVars

/* Load global page-wide variables from <script id="pagevars">...</script> and store them into window.pageVars */
var e = document.getElementById('pagevars');
window.pageVars = e ? JSON.parse(e.innerHTML) : {};
