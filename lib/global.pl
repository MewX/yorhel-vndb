package VNDB;

our @DBLOGIN = ( 'dbi:Pg:dbname=vndb', 'vndb', 'passwd' );
our @SHMOPTS = ( -key => 'VNDB', -create => 'yes', -destroy => 'no', -mode => 0666);
our $DEBUG = 1;
our $VERSION = 'svn';
our $COOKEY = '73jkS39Sal2)'; # encryption key for cookies (not to worry, this one is fake)

our $MULTI = [
  RG => {},
  Image => {},
  Sitemap => {},
  #Anime => { user => '', pass => ''  },
  Maintenance => {},
  #IRC => { user => 'Multi'},
];

our %VNDBopts = (
  CookieDomain  => '.vndb.org',
  root_url      => 'http://vndb.org',
  static_url    => 'http://static.vndb.org',
  tplopts       => {
    filename      => 'main',
    searchdir     => '/www/vndb/data/tpl',
    compiled      => '/www/vndb/data/tplcompiled.pm',
    namespace     => 'VNDB::Util::Template::tpl',
    pre_chomp     => 1,
    post_chomp    => 1,
    rm_newlines   => 0,
    deep_reload   => 1,
  },
  ranks  => [
    [ [ qw| visitor loser user mod admin | ], [] ],
    {map{$_,1}qw| hist                                          |}, # 0 - visitor (not logged in)
    {map{$_,1}qw| hist                                          |}, # 1 - loser
    {map{$_,1}qw| hist board edit                               |}, # 2 - user
    {map{$_,1}qw| hist board boardmod edit mod lock del         |}, # 3 - mod
    {map{$_,1}qw| hist board boardmod edit mod lock del usermod |}, # 4 - admin
  ],
  postsperpage => 25,
  imgpath => '/www/vndb/static/cv', # cover images
  sfpath  => '/www/vndb/static/sf', # full-size screenshots
  stpath  => '/www/vndb/static/st', # screenshot thumbnails
  mappath => '/www/vndb/data/rg',   # image maps for the relation graphs
  docpath => '/www/vndb/data/docs',
);
$VNDBopts{ranks}[0][1] = { (map{$_,1} map { keys %{$VNDBopts{ranks}[$_]} } 1..5) };


# I wonder why I even made this hash, almost everything is still hardcoded anyway...
our $DTAGS = {
  an => 'Announcements',    # 0   - usage restricted to boardmods
  db => 'VNDB Discussions', # 0
  v  => 'Visual novels',    # vid
  p  => 'Producers',        # pid
  u  => 'Users',            # uid
};


our $PLAT = {
  win => 'Windows',
  lin => 'Linux',
  mac => 'Mac OS',
  dvd => 'DVD Player',
  gba => 'Game Boy Advance',
  msx => 'MSX',
  nds => 'Nintendo DS',
  nes => 'Famicom',
  psp => 'Playstation Portable',
  ps1 => 'Playstation 1',
  ps2 => 'Playstation 2',
  ps3 => 'Playstation 3',
  drc => 'Dreamcast',
  sfc => 'Super Nintendo',
  wii => 'Nintendo Wii',
  xb3 => 'Xbox 360',
  oth => 'Other'
};


# NOTE: don't forget to update dyna.js
our $MED = {
  cd  => 'CD',
  dvd => 'DVD',
  gdr => 'GD-ROM',
  blr => 'Blu-Ray disk',
  in  => 'Internet download',
  pa  => 'Patch',
  otc => 'Other (console)',
};


our $PROT = {
  co => 'Company',
  in => 'Individual',
  ng => 'Amateur group',
};


our $RTYP = [
  'Complete',
  'Partial',
  'Trial'
];


# Yes, this is the category list. No, changing something here may
# not change it on the entire site - many things are still hardcoded
our $CAT = {
  g => [ 'Gameplay', {
    aa => 'Visual Novel', # 0..1
    ab => 'Adventure',    # 0..1
    ac => "Act\x{200B}ion",      # Ugliest. Hack. Ever.
    rp => 'RPG',
    st => 'Strategy',
    si => 'Simulation',
  }, 2 ],
  p => [ 'Plot', {        # 0..1
    li => 'Linear',
    br => 'Branching',
  }, 3 ],
  e => [ 'Elements', {
    ac => 'Action',
    co => 'Comedy',
    dr => 'Drama',
    fa => 'Fantasy',
    ho => 'Horror',
    my => 'Mystery',
    ro => 'Romance',
    sc => 'School Life',
    sf => 'SciFi', 
    sj => 'Shoujo Ai',
    sn => 'Shounen Ai',
  }, 1 ],
  t => [ 'Time', {        # 0..1
    fu => 'Future',
    pa => 'Past', 
    pr => 'Present',
  }, 4 ],
  l => [ 'Place', {       # 0..1
    ea => 'Earth', 
    fa => "Fant\x{200B}asy world",
    sp => 'Space',
  }, 5 ],
  h => [ 'Protagonist', { # 0..1
    fa => 'Male',
    fe => "Fem\x{200B}ale",
  }, 6 ],
  s => [ 'Sexual content', {
    aa => 'Sexual content',
    be => 'Bestiality',
    in => 'Incest',
    lo => 'Lolicon',
    sh => 'Shotacon',
    ya => 'Yaoi',
    yu => 'Yuri',
    ra => 'Rape',
  }, 7 ],
};


our $RSTAT = [
  'Unknown',
  'Pending',
  'Obtained',   # hardcoded
  'On loan',
  'Deleted',
];
our $VSTAT = [
  'Unknown',
  'Playing',
  'Finished', # hardcoded
  'Stalled',
  'Dropped',
];

our $WSTAT = [
  'High',
  'Medium',
  'Low',
  'Blacklist',
];


# OLD
our $LSTAT = [
  'Wishlist',
  'Blacklist',
  'Playing',
  'Finished',
  'Stalled',
  'Dropped',
  'Other', # XXX: hardcoded at 6
];


our $VREL = [
  'Sequel',
  'Prequel',     # 1
  'Same setting',
  'Alternative setting',
  'Alternative version',
  'Same characters',
  'Side story',
  'Parent story',# 7
  'Summary',
  'Full story',  # 9
  'Other',
];
# these reverse relations need a [relation]-1
our $VRELW = {map{$_=>1}qw| 1 7 9 |};


# users.flags
our $UFLAGS = {
  list => 4,
  nsfw => 8,
};


our $VNLEN = [
  [ 'Unkown',     '',              '' ],
  [ 'Very short', '< 2 hours',     'OMGWTFOTL, A Dream of Summer' ],
  [ 'Short',      '2 - 10 hours',  'Narcissu, Planetarian' ],
  [ 'Medium',     '10 - 30 hours', 'Kana: Little Sister' ],
  [ 'Long',       '30 - 50 hours', 'Tsukihime' ],
  [ 'Very long',  '> 50 hours',    'Clannad' ],
];


our $VRAGES = {
  -1 => 'Unknown',
  0  => 'All ages',
  map { $_ => $_.'+' } 6..18
};


our $ANITYPE = [
  # VNDB          AniDB
  [ 'unknown',    'unknown',    ],
  [ 'TV',         'TV Series'   ],
  [ 'OVA',        'OVA'         ],
  [ 'Movie',      'Movie'       ],
  [ 'unknown',    'Other'       ],
  [ 'unknown',    'Web'         ],
  [ 'TV Special', 'TV Special'  ],
  [ 'unknown',    'Music Video' ],
];
# AniDB defines:
#  id="1", name="unknown
#  id="2", name="TV Series
#  id="3", name="OVA
#  id="4", name="Movie
#  id="5", name="Other
#  id="6", name="Web
#  id="7", name="TV Special
#  id="8", name="Music Video





our $LANG = {
# 'aa'         => q|Afar|,
# 'ab'         => q|Abkhazian|,
# 'ace'        => q|Achinese|,
# 'ach'        => q|Acoli|,
# 'ada'        => q|Adangme|,
# 'ady'        => q|Adyghe|,
# 'ae'         => q|Avestan|,
# 'af'         => q|Afrikaans|,
# 'afh'        => q|Afrihili|,
# 'ak'         => q|Akan|,
# 'akk'        => q|Akkadian|,
# 'ale'        => q|Aleut|,
# 'alg'        => q|Algonquian languages|,
# 'am'         => q|Amharic|,
# 'an'         => q|Aragonese|,
# 'apa'        => q|Apache languages|,
# 'ar'         => q|Arabic|,
# 'arc'        => q|Aramaic|,
# 'arn'        => q|Araucanian|,
# 'arp'        => q|Arapaho|,
# 'arw'        => q|Arawak|,
# 'as'         => q|Assamese|,
# 'ast'        => q|Asturian|,
# 'ath'        => q|Athapascan languages|,
# 'aus'        => q|Australian languages|,
# 'av'         => q|Avaric|,
# 'awa'        => q|Awadhi|,
# 'ay'         => q|Aymara|,
# 'az'         => q|Azerbaijani|,
# 'ba'         => q|Bashkir|,
# 'bad'        => q|Banda|,
# 'bai'        => q|Bamileke languages|,
# 'bal'        => q|Baluchi|,
# 'ban'        => q|Balinese|,
# 'bas'        => q|Basa|,
# 'be'         => q|Belarusian|,
# 'bej'        => q|Beja|,
# 'bem'        => q|Bemba|,
# 'bg'         => q|Bulgarian|,
# 'bh'         => q|Bihari|,
# 'bho'        => q|Bhojpuri|,
# 'bi'         => q|Bislama|,
# 'bik'        => q|Bikol|,
# 'bin'        => q|Bini|,
# 'bla'        => q|Siksika|,
# 'bm'         => q|Bambara|,
# 'bn'         => q|Bengali|,
# 'bo'         => q|Tibetan|,
# 'br'         => q|Breton|,
# 'bra'        => q|Braj|,
# 'bs'         => q|Bosnian|,
# 'btk'        => q|Batak (Indonesia)|,
# 'bua'        => q|Buriat|,
# 'bug'        => q|Buginese|,
# 'ca'         => q|Catalan|,
# 'cad'        => q|Caddo|,
# 'car'        => q|Carib|,
# 'ce'         => q|Chechen|,
# 'ceb'        => q|Cebuano|,
# 'ch'         => q|Chamorro|,
# 'chb'        => q|Chibcha|,
# 'chg'        => q|Chagatai|,
# 'chk'        => q|Chuukese|,
# 'chm'        => q|Mari|,
# 'chn'        => q|Chinook Jargon|,
# 'cho'        => q|Choctaw|,
# 'chp'        => q|Chipewyan|,
# 'chr'        => q|Cherokee|,
# 'chy'        => q|Cheyenne|,
# 'cmc'        => q|Chamic languages|,
# 'co'         => q|Corsican|,
# 'cop'        => q|Coptic|,
# 'cr'         => q|Cree|,
# 'crh'        => q|Crimean Turkish|,
 'cs'         => q|Czech|,
# 'csb'        => q|Kashubian|,
# 'cu'         => q|Church Slavic|,
# 'cv'         => q|Chuvash|,
# 'cy'         => q|Welsh|,
 'da'         => q|Danish|,
# 'dak'        => q|Dakota|,
# 'dar'        => q|Dargwa|,
# 'day'        => q|Dayak|,
 'de'         => q|German|,
# 'del'        => q|Delaware|,
# 'dgr'        => q|Dogrib|,
# 'din'        => q|Dinka|,
# 'doi'        => q|Dogri|,
# 'dua'        => q|Duala|,
# 'dv'         => q|Divehi|,
# 'dyu'        => q|Dyula|,
# 'dz'         => q|Dzongkha|,
# 'ee'         => q|Ewe|,
# 'efi'        => q|Efik|,
# 'eka'        => q|Ekajuk|,
# 'el'         => q|Modern Greek|,
# 'elx'        => q|Elamite|,
 'en'         => q|English|,
# 'eo'         => q|Esperanto|,
 'es'         => q|Spanish|,
# 'et'         => q|Estonian|,
# 'eu'         => q|Basque|,
# 'ewo'        => q|Ewondo|,
# 'fa'         => q|Persian|,
# 'fan'        => q|Fang|,
# 'fat'        => q|Fanti|,
# 'ff'         => q|Fulah|,
 'fi'         => q|Finnish|,
# 'fj'         => q|Fijian|,
# 'fo'         => q|Faroese|,
# 'fon'        => q|Fon|,
 'fr'         => q|French|,
# 'fur'        => q|Friulian|,
# 'fy'         => q|Frisian|,
# 'ga'         => q|Irish|,
# 'gaa'        => q|Ga|,
# 'gay'        => q|Gayo|,
# 'gba'        => q|Gbaya|,
# 'gd'         => q|Scots Gaelic|,
# 'gez'        => q|Geez|,
# 'gil'        => q|Gilbertese|,
# 'gl'         => q|Gallegan|,
# 'gn'         => q|Guarani|,
# 'gon'        => q|Gondi|,
# 'gor'        => q|Gorontalo|,
# 'got'        => q|Gothic|,
# 'grb'        => q|Grebo|,
# 'grc'        => q|Ancient Greek|,
# 'gu'         => q|Gujarati|,
# 'gv'         => q|Manx|,
# 'gwi'        => q|Gwich'in|,
# 'ha'         => q|Hausa|,
# 'hai'        => q|Haida|,
# 'haw'        => q|Hawaiian|,
# 'he'         => q|Hebrew|,
# 'hi'         => q|Hindi|,
# 'hil'        => q|Hiligaynon|,
# 'him'        => q|Himachali|,
# 'hit'        => q|Hittite|,
# 'hmn'        => q|Hmong|,
# 'ho'         => q|Hiri Motu|,
# 'hr'         => q|Croatian|,
# 'ht'         => q|Haitian|,
# 'hu'         => q|Hungarian|,
# 'hup'        => q|Hupa|,
# 'hy'         => q|Armenian|,
# 'hz'         => q|Herero|,
# 'i-ami'      => q|Ami|,
# 'i-bnn'      => q|Bunun|,
# 'i-klingon'  => q|Klingon|,
# 'i-mingo'    => q|Mingo|,
# 'i-pwn'      => q|Paiwan|,
# 'i-tao'      => q|Tao|,
# 'i-tay'      => q|Tayal|,
# 'i-tsu'      => q|Tsou|,
# 'iba'        => q|Iban|,
# 'id'         => q|Indonesian|,
# 'ie'         => q|Interlingue|,
# 'ig'         => q|Igbo|,
# 'ii'         => q|Sichuan Yi|,
# 'ijo'        => q|Ijo|,
# 'ik'         => q|Inupiaq|,
# 'ilo'        => q|Iloko|,
# 'inh'        => q|Ingush|,
# 'io'         => q|Ido|,
# 'iro'        => q|Iroquoian languages|,
# 'is'         => q|Icelandic|,
 'it'         => q|Italian|,
# 'iu'         => q|Inuktitut|,
 'ja'         => q|Japanese|,
# 'jpr'        => q|Judeo-Persian|,
# 'jrb'        => q|Judeo-Arabic|,
# 'jv'         => q|Javanese|,
# 'ka'         => q|Georgian|,
# 'kaa'        => q|Kara-Kalpak|,
# 'kab'        => q|Kabyle|,
# 'kac'        => q|Kachin|,
# 'kam'        => q|Kamba|,
# 'kar'        => q|Karen|,
# 'kaw'        => q|Kawi|,
# 'kbd'        => q|Kabardian|,
# 'kg'         => q|Kongo|,
# 'kha'        => q|Khasi|,
# 'kho'        => q|Khotanese|,
# 'ki'         => q|Kikuyu|,
# 'kj'         => q|Kuanyama|,
# 'kk'         => q|Kazakh|,
# 'kl'         => q|Kalaallisut|,
# 'km'         => q|Khmer|,
# 'kmb'        => q|Kimbundu|,
# 'kn'         => q|Kannada|,
 'ko'         => q|Korean|,
# 'kok'        => q|Konkani|,
# 'kos'        => q|Kosraean|,
# 'kpe'        => q|Kpelle|,
# 'kr'         => q|Kanuri|,
# 'krc'        => q|Karachay-Balkar|,
# 'kro'        => q|Kru|,
# 'kru'        => q|Kurukh|,
# 'ks'         => q|Kashmiri|,
# 'ku'         => q|Kurdish|,
# 'kum'        => q|Kumyk|,
# 'kut'        => q|Kutenai|,
# 'kv'         => q|Komi|,
# 'kw'         => q|Cornish|,
# 'ky'         => q|Kirghiz|,
# 'la'         => q|Latin|,
# 'lad'        => q|Ladino|,
# 'lah'        => q|Lahnda|,
# 'lam'        => q|Lamba|,
# '#lb'         => q|Letzeburgesch|,
# 'lez'        => q|Lezghian|,
# 'lg'         => q|Ganda|,
# 'li'         => q|Limburgish|,
# 'ln'         => q|Lingala|,
# 'lo'         => q|Lao|,
# 'lol'        => q|Mongo|,
# 'loz'        => q|Lozi|,
# 'lt'         => q|Lithuanian|,
# 'lu'         => q|Luba-Katanga|,
# 'lua'        => q|Luba-Lulua|,
# 'lui'        => q|Luiseno|,
# 'lun'        => q|Lunda|,
# 'luo'        => q|Luo (Kenya and Tanzania)|,
# 'lus'        => q|Lushai|,
# 'lv'         => q|Latvian|,
# 'mad'        => q|Madurese|,
# 'mag'        => q|Magahi|,
# 'mai'        => q|Maithili|,
# 'mak'        => q|Makasar|,
# 'man'        => q|Mandingo|,
# 'mas'        => q|Masai|,
# 'mdf'        => q|Moksha|,
# 'mdr'        => q|Mandar|,
# 'men'        => q|Mende|,
# 'mg'         => q|Malagasy|,
# 'mh'         => q|Marshall|,
# 'mi'         => q|Maori|,
# 'mic'        => q|Micmac|,
# 'min'        => q|Minangkabau|,
# 'mk'         => q|Macedonian|,
# 'ml'         => q|Malayalam|,
# 'mn'         => q|Mongolian|,
# 'mnc'        => q|Manchu|,
# 'mni'        => q|Manipuri|,
# 'mno'        => q|Manobo languages|,
# 'mo'         => q|Moldavian|,
# 'moh'        => q|Mohawk|,
# 'mos'        => q|Mossi|,
# 'mr'         => q|Marathi|,
# 'ms'         => q|Malay|,
# 'mt'         => q|Maltese|,
# 'mul'        => q|Multiple languages|,
# 'mun'        => q|Munda languages|,
# 'mus'        => q|Creek|,
# 'mwr'        => q|Marwari|,
# 'my'         => q|Burmese|,
# 'myn'        => q|Mayan languages|,
# 'myv'        => q|Erzya|,
# 'na'         => q|Nauru|,
# 'nah'        => q|Nahuatl|,
# 'nap'        => q|Neapolitan|,
# 'nb'         => q|Norwegian Bokmal|,
# 'nd'         => q|North Ndebele|,
# 'ne'         => q|Nepali|,
# 'new'        => q|Newari|,
# 'ng'         => q|Ndonga|,
# 'nia'        => q|Nias|,
# 'niu'        => q|Niuean|,
 'nl'         => q|Dutch|,
 'no'         => q|Norwegian|,
# 'nog'        => q|Nogai|,
# 'non'        => q|Old Norse|,
# 'nr'         => q|South Ndebele|,
# 'nso'        => q|Northern Sotho|,
# 'nub'        => q|Nubian languages|,
# 'nv'         => q|Navajo|,
# 'ny'         => q|Chichewa|,
# 'nym'        => q|Nyamwezi|,
# 'nyn'        => q|Nyankole|,
# 'nyo'        => q|Nyoro|,
# 'nzi'        => q|Nzima|,
# 'oj'         => q|Ojibwa|,
# 'om'         => q|Oromo|,
# 'or'         => q|Oriya|,
# 'os'         => q|Ossetian; Ossetic|,
# 'osa'        => q|Osage|,
# 'oto'        => q|Otomian languages|,
# 'pa'         => q|Panjabi|,
# 'pag'        => q|Pangasinan|,
# 'pal'        => q|Pahlavi|,
# 'pam'        => q|Pampanga|,
# 'pap'        => q|Papiamento|,
# 'pau'        => q|Palauan|,
# 'phn'        => q|Phoenician|,
# 'pi'         => q|Pali|,
 'pl'         => q|Polish|,
# 'pon'        => q|Pohnpeian|,
# 'pra'        => q|Prakrit languages|,
# 'ps'         => q|Pushto|,
 'pt'         => q|Portuguese|,
# 'pt-br'      => q|Brazilian Portuguese|,
# 'pt-pt'      => q|Portugal Portuguese|,
# 'qu'         => q|Quechua|,
# 'raj'        => q|Rajasthani|,
# 'rap'        => q|Rapanui|,
# 'rar'        => q|Rarotongan|,
# 'rm'         => q|Raeto-Romance|,
# 'rn'         => q|Rundi|,
# 'ro'         => q|Romanian|,
# 'rom'        => q|Romany|,
 'ru'         => q|Russian|,
# 'rw'         => q|Kinyarwanda|,
# 'sa'         => q|Sanskrit|,
# 'sad'        => q|Sandawe|,
# 'sah'        => q|Yakut|,
# 'sal'        => q|Salishan languages|,
# 'sam'        => q|Samaritan Aramaic|,
# 'sas'        => q|Sasak|,
# 'sat'        => q|Santali|,
# 'sc'         => q|Sardinian|,
# 'sco'        => q|Scots|,
# 'sd'         => q|Sindhi|,
# 'se'         => q|Northern Sami|,
# 'sel'        => q|Selkup|,
# 'sg'         => q|Sango|,
# 'shn'        => q|Shan|,
# 'si'         => q|Sinhalese|,
# 'sid'        => q|Sidamo|,
# 'sio'        => q|Siouan languages|,
# 'sk'         => q|Slovak|,
# 'sl'         => q|Slovenian|,
# 'sm'         => q|Samoan|,
# 'sma'        => q|Southern Sami|,
# 'smj'        => q|Lule Sami|,
# 'smn'        => q|Inari Sami|,
# 'sms'        => q|Skolt Sami|,
# 'sn'         => q|Shona|,
# 'snk'        => q|Soninke|,
# 'so'         => q|Somali|,
# 'sog'        => q|Sogdian|,
# 'son'        => q|Songhai|,
# 'sq'         => q|Albanian|,
# 'sr'         => q|Serbian|,
# 'srr'        => q|Serer|,
# 'ss'         => q|Swati|,
# 'st'         => q|Southern Sotho|,
# 'su'         => q|Sundanese|,
# 'suk'        => q|Sukuma|,
# 'sus'        => q|Susu|,
# 'sux'        => q|Sumerian|,
 'sv'         => q|Swedish|,
# 'sw'         => q|Swahili|,
# 'syr'        => q|Syriac|,
# 'ta'         => q|Tamil|,
# 'te'         => q|Telugu|,
# 'tem'        => q|Timne|,
# 'ter'        => q|Tereno|,
# 'tet'        => q|Tetum|,
# 'tg'         => q|Tajik|,
# 'th'         => q|Thai|,
# 'ti'         => q|Tigrinya|,
# 'tig'        => q|Tigre|,
# 'tiv'        => q|Tiv|,
# 'tk'         => q|Turkmen|,
# 'tkl'        => q|Tokelau|,
# 'tl'         => q|Tagalog|,
# 'tli'        => q|Tlingit|,
# 'tmh'        => q|Tamashek|,
# 'tn'         => q|Tswana|,
# 'to'         => q|Tonga (Tonga Islands)|,
# 'tog'        => q|Tonga (Nyasa)|,
# 'tpi'        => q|Tok Pisin|,
 'tr'         => q|Turkish|,
# 'ts'         => q|Tsonga|,
# 'tsi'        => q|Tsimshian|,
# 'tt'         => q|Tatar|,
# 'tum'        => q|Tumbuka|,
# 'tup'        => q|Tupi languages|,
# 'tvl'        => q|Tuvalu|,
# 'tw'         => q|Twi|,
# 'ty'         => q|Tahitian|,
# 'tyv'        => q|Tuvinian|,
# 'udm'        => q|Udmurt|,
# 'ug'         => q|Uighur|,
# 'uga'        => q|Ugaritic|,
# 'uk'         => q|Ukrainian|,
# 'umb'        => q|Umbundu|,
# 'ur'         => q|Urdu|,
# 'uz'         => q|Uzbek|,
# 'vai'        => q|Vai|,
# 've'         => q|Venda|,
# 'vi'         => q|Vietnamese|,
# 'vo'         => q|Volapuk|,
# 'vot'        => q|Votic|,
# 'wa'         => q|Walloon|,
# 'wak'        => q|Wakashan languages|,
# 'wal'        => q|Walamo|,
# 'war'        => q|Waray|,
# 'was'        => q|Washo|,
# 'wen'        => q|Sorbian languages|,
# 'wo'         => q|Wolof|,
# 'xal'        => q|Kalmyk|,
# 'xh'         => q|Xhosa|,
# 'yao'        => q|Yao|,
# 'yap'        => q|Yapese|,
# 'yi'         => q|Yiddish|,
# 'yo'         => q|Yoruba|,
# 'ypk'        => q|Yupik languages|,
# 'za'         => q|Zhuang|,
# 'zap'        => q|Zapotec|,
# 'zen'        => q|Zenaga|,
 'zh'         => q|Chinese|,
# 'znd'        => q|Zande|,
# 'zu'         => q|Zulu|,
# 'zun'        => q|Zuni|,
};


# override config vars
require '/www/vndb/data/config.pl' if -e '/www/vndb/data/config.pl';


1;

