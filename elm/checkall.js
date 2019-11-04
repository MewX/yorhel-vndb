/* "checkall" checkbox, usage:
 *
 *    <input type="checkbox" class="checkall" name="$somename">
 *
 *  Checking that will synchronize all other checkboxes with name="$somename".
 */
document.querySelectorAll('input[type=checkbox].checkall').forEach(function(el) {
    el.addEventListener('click', function() {
        document.querySelectorAll('input[type=checkbox][name="'+el.name+'"]').forEach(function(el2) {
            if(el2.checked != el.checked)
                el2.click();
        });
    });
});
