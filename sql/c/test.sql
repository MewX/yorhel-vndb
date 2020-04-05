-- should all fail
select 's+10'::vndbid;
select 's 10'::vndbid;
select ' s10'::vndbid;
select 's10 '::vndbid;
select 's01'::vndbid;
select 'x01'::vndbid;
select 'x1'::vndbid;
select 'v0'::vndbid;
select 'v'::vndbid;
select ''::vndbid;
select 'cx1'::vndbid;
select 'chx1'::vndbid;
select 'v67108864'::vndbid;

-- Should all return their input
select 'c123456'::vndbid;
select 'p789000'::vndbid;
select 'v67108863'::vndbid;
select 'r10'::vndbid;
select 'i10'::vndbid;
select 'g10'::vndbid;
select 's10'::vndbid;
select 'ch10'::vndbid;
select 'cv10'::vndbid;
select 'sf10'::vndbid;

select 's11'::vndbid = 's11'::vndbid; -- t
select 's11'::vndbid = 'v11'::vndbid; -- f
select 's11'::vndbid <> 's11'::vndbid; -- f
select 's11'::vndbid <> 'v11'::vndbid; -- t
select 's11'::vndbid > 's11'::vndbid; -- f
select 's11'::vndbid > 's10'::vndbid; -- t
select 's11'::vndbid >= 's11'::vndbid; -- t
select 's11'::vndbid >= 's10'::vndbid; -- t
select 's11'::vndbid >= 's12'::vndbid; -- f

select vndbid_type('sf1'); -- 'sf'
select vndbid_type('v1'); -- 'v'

select vndbid_num('sf1'); -- 1
select vndbid_num('v5'); -- 5
select vndbid_num('v67108863'); -- large

select vndbid('s', 1); -- 's1'
select vndbid('sf', 500); -- 'sf500'
select vndbid('s', 0); -- fail
select vndbid('x', 1); -- fail
select vndbid('s', 67108864); -- fail

-- The functions probably aren't even called, so not sure if this is a good test.
select vndbid_le(NULL, 'sf1'); -- NULL
select vndbid(NULL, 1); -- NULL
