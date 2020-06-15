// @license magnet:?xt=urn:btih:0b31508aeb0634b347b8270c7bee4d411b5d4109&dn=agpl-3.0.txt AGPL-3.0-only
// @source: https://code.blicky.net/yorhel/vndb/src/branch/master/data/js
// SPDX-License-Identifier: AGPL-3.0-only


/* This is the main Javascript file. This file is processed by util/jsgen.pl to
 * generate the final JS file(s) used by the site. */

// Variables from jsgen.pl
VARS = /*VARS*/;

// Relic of the past
VARS.resolutions = [
    ["unknown","Unknown / console / handheld"],
    ["nonstandard","Non-standard"],
    ["4:3",["640x480","640x480"],["800x600","800x600"],["1024x768","1024x768"],["1280x960","1280x960"],["1600x1200","1600x1200"]],
    ["widescreen",["640x400","640x400"],["960x600","960x600"],["960x640","960x640"],["1024x576","1024x576"],["1024x600","1024x600"],["1024x640","1024x640"],["1280x720","1280x720"],["1280x800","1280x800"],["1366x768","1366x768"],["1600x900","1600x900"],["1920x1080","1920x1080"]]
];

/* The include directives below automatically wrap the file contents inside an
 * anonymous function, so each file has its own local namespace. Included files
 * can't access variables or functions from other files, unless these variables
 * are explicitely shared in DOM objects or (more commonly) the global 'window'
 * object.
 */

// Reusable library functions
//include lib.js

// Reusable widgets
//include iv.js
//include dropdown.js
//include dateselector.js
//include dropdownsearch.js
//include tabs.js

// Page/functionality-specific widgets
//include filter.js
//include misc.js

// VN editing (/v+/edit)
//include vnrel.js
//include vnscr.js
//include vnstaff.js
//include vncast.js

// Producer editing (/p+/edit)
//include prodrel.js

// @license-end
