/* Spoiler hiding, works in tandem with the .spoillvl-x and .spoil-x classes.
 * Usage:
 *   <a href="#" class="spoilset-0" data-target="someclass">hide spoilers</a>
 *   <div class="someclass spoillvl-0">
 *     <span class="spoil-1">minor spoiler</span>
 *   </div>
 */
document.querySelectorAll('.spoilset-0, .spoilset-1, .spoilset-2').forEach(function(a) {
    a.addEventListener('click', function(ev) {
        var lvl = a.classList.contains('spoilset-0') ? 0 : a.classList.contains('spoilset-1') ? 1 : 2;
        var t = document.querySelector('.'+a.getAttribute('data-target'));
        t.classList.toggle('spoillvl-0', lvl == 0);
        t.classList.toggle('spoillvl-1', lvl == 1);
        t.classList.toggle('spoillvl-2', lvl == 2);

        // Updating the visual selected status of the links depends on context, the following is for use in 'maintabs' links.
        // XXX: This would be nicer when done in CSS.
        var p = a.closest('div.maintabs');
        if(p) {
            p.querySelector('.spoilset-0').parentNode.classList.toggle('tabselected', lvl == 0);
            p.querySelector('.spoilset-1').parentNode.classList.toggle('tabselected', lvl == 1);
            p.querySelector('.spoilset-2').parentNode.classList.toggle('tabselected', lvl == 2);
        }
        ev.preventDefault();
        return false;
    });
});
