function vncLoad() {
  var cast = jsonParse(byId('seiyuu').value) || [];
  var copt = byId('cast_chars').options;
  var chars = {};
  for(var i = 0; i < copt.length; i++) {
    if(copt[i].value)
      chars[copt[i].value] = copt[i].text;
  }
  cast.sort(function(a, b) {
    if(chars[a.cid] < chars[b.cid]) return -1;
    if(chars[a.cid] > chars[b.cid]) return 1;
    return 0;
  });
  for(var i = 0; i < cast.length; i++) {
    var aid = cast[i].aid;
    if(vnsStaffData[aid]) // vnsStaffData is filled by vnsLoad()
      vncAdd(vnsStaffData[aid], cast[i].cid, cast[i].note);
  }
  vncEmpty();

  onSubmit(byName(byId('maincontent'), 'form')[0], vncSerialize);

  // dropdown search
  dsInit(byId('cast_input'), '/xml/staff.xml?q=', function(item, tr) {
    tr.appendChild(tag('td', { style: 'text-align: right; padding-right: 5px'}, 's'+item.getAttribute('sid')));
    tr.appendChild(tag('td', item.firstChild.nodeValue));
    tr.appendChild(tag('td', item.getAttribute('orig')));
  }, vncFormAdd);
}

function vncAdd(seiyuu, chr, note) {
  var tbl = byId('cast_tbl');

  var csel = byId('cast_chars').cloneNode(true);
  csel.removeAttribute('id');
  csel.value = chr;

  tbl.appendChild(tag('tr', {id:'vnc_a'+seiyuu.aid},
    tag('td', {'class':'tc_char'}, csel),
    tag('td', {'class':'tc_name'},
      tag('input', {type:'hidden', value:seiyuu.aid}),
      tag('a', {href:'/s'+seiyuu.id}, seiyuu.name)),
    tag('td', {'class':'tc_note'}, tag('input', {type:'text', 'class':'text', value:note})),
    tag('td', {'class':'tc_del'}, tag('a', {href:'#', onclick:vncDel}, 'remove'))
  ));
  vncEmpty();
  vncSerialize();
}

function vncFormAdd(item) {
  var chr = byId('cast_chars').value;
  if (chr) {
    var s = { id:item.getAttribute('sid'), aid:item.getAttribute('id'), name:item.firstChild.nodeValue };
    vncAdd(s, chr, '');
  } else
    alert('Select character first please.');
  return '';
}

function vncEmpty() {
  var x = byId('cast_loading');
  var tbody = byId('cast_tbl');
  var tbl = tbody.parentNode;
  var thead = byName(tbl, 'thead');
  if(x)
    tbody.removeChild(x);
  if(byName(tbody, 'tr').length < 1) {
    tbody.appendChild(tag('tr', {id:'cast_tr_none'},
      tag('td', {colspan:4}, 'None')));
    if (thead.length)
      tbl.removeChild(thead[0]);
  } else {
    if(byId('cast_tr_none'))
      tbody.removeChild(byId('cast_tr_none'));
    if (thead.length < 1) {
      thead = tag('thead', tag('tr',
        tag('td', {'class':'tc_char'}, 'Character'),
        tag('td', {'class':'tc_name'}, 'Seiyuu'),
        tag('td', {'class':'tc_note'}, 'Note'),
        tag('td', '')));
      tbl.insertBefore(thead, tbody);
    }
  }
}

function vncSerialize() {
  var l = byName(byId('cast_tbl'), 'tr');
  var c = [];
  for (var i = 0; i < l.length; i++) {
    if(l[i].id == 'cast_tr_none')
      continue;
    var aid  = byName(byClass(l[i], 'tc_name')[0], 'input')[0];
    var role = byName(byClass(l[i], 'tc_char')[0], 'select')[0];
    var note = byName(byClass(l[i], 'tc_note')[0], 'input')[0];
    c.push({ aid:Number(aid.value), cid:Number(role.value), note:note.value });
  }
  byId('seiyuu').value = JSON.stringify(c);
  return true;
}

function vncDel() {
  var tr = this;
  while (tr.nodeName.toLowerCase() != 'tr')
    tr = tr.parentNode;
  byId('cast_tbl').removeChild(tr);
  vncEmpty();
  vncSerialize();
  return false;
}

if(byId('jt_box_vn_cast'))
  vncLoad();
