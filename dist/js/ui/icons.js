'use strict';
/** One local line-icon family; map abbreviations (WC/P/H) remain legible at small scales. */
function uiIcon(type){
  const paths={office:'M5 20V4h14v16M9 20v-5h6v5M9 8h1m4 0h1M9 11h1m4 0h1',classroom:'M3 4h18v13H3zM8 21l4-4 4 4M7 9h10m-10 4h6',service:'M5 4h14v16H5zM9 8h6m-6 4h6m-6 4h2',wc:'M8 4h.01M16 4h.01M7 8h2v7H7zm8 0h2v7h-2zM7 15v5m2-5v5m6-5v5m2-5v5',stairs:'M3 20h5v-5h5v-5h5V5h3',lift:'M5 3h14v18H5zM9 10l3-3 3 3m-6 4 3 3 3-3',entrance:'M13 4h7v16h-7M3 12h12m-4-4 4 4-4 4',gate:'M13 4h7v16h-7M3 12h12m-4-4 4 4-4 4',parking:'M5 20V4h8a5 5 0 0 1 0 10H5',bicycle:'M9 17a4 4 0 1 1-8 0 4 4 0 0 1 8 0m14 0a4 4 0 1 1-8 0 4 4 0 0 1 8 0M5 17l5-9 5 9M8 8h9M14 5h3l2 12',bus:'M5 17V5q7-4 14 0v12H5zM5 10h14M7 17v3m10-3v3M8 14h.01m8 0h.01',smoking:'M3 14h16v4H3zm18 0v4M8 3q-4 3 0 6m5-6q-4 3 0 6',tip:'m12 3 3 6 7 1-5 5 1 7-6-3-6 3 1-7-5-5 7-1z',corridor:'M3 5h18v14H3zM6 12h12m-3-3 3 3-3 3'};
  return `<svg class="ui-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${paths[type]||'M5 5h14v14H5zM9 12h6m-3-3v6'}"/></svg>`
}
