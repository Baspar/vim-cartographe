nnoremap <leader><leader>g :CartographeNav<CR>

command! -nargs=1 -complete=customlist,cartographe#CartographeComplete CartographeComp call cartographe#CartographeListComponents('<args>')
command! -nargs=? -complete=customlist,cartographe#CartographeComplete CartographeNav  call cartographe#CartographeNavigate('<args>', 'edit')
command! -nargs=? -complete=customlist,cartographe#CartographeComplete CartographeNavS call cartographe#CartographeNavigate('<args>', 'split')
command! -nargs=? -complete=customlist,cartographe#CartographeComplete CartographeNavV call cartographe#CartographeNavigate('<args>', 'vsplit')
