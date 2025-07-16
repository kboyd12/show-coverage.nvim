" Prevent loading plugin multiple times
if exists('g:loaded_show_coverage')
  finish
endif
let g:loaded_show_coverage = 1

" Create user commands
command! CoverageShow lua require('show-coverage').show()
command! CoverageHide lua require('show-coverage').hide()
command! CoverageToggle lua require('show-coverage').toggle()
command! CoverageRefresh lua require('show-coverage').refresh()
command! CoverageAutoEnable lua require('show-coverage').enable_auto_show()
command! CoverageAutoDisable lua require('show-coverage').disable_auto_show()
