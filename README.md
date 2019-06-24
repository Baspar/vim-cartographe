# vim-cartographe

## Example configuration
```vim
let g:CartographeMap =
            \ {
            \   'src/main/components/': {
            \     '{NAME:pascal}/index.js'                      : 'index',
            \     '{NAME:pascal}/{NAME:pascal}.js'              : 'pure',
            \     '{NAME:pascal}/styledComponents.js'           : 'styled'
            \   },
            \   'src/main/redux/': {
            \     '{NAME:pascal}/saga.js'                       : 'saga',
            \     '{NAME:pascal}/reducer.js'                    : 'reducer',
            \     '{NAME:pascal}/selector.js'                   : 'selector',
            \     '{NAME:pascal}/api.js'                        : 'api',
            \     '{NAME:pascal}/action.js'                     : 'action'
            \   },
            \   'src/test/components/': {
            \     '{NAME:pascal}/index.spec.js'                 : 'indexSpec',
            \     '{NAME:pascal}/{NAME:pascal}.spec.js'         : 'pureSpec',
            \     '{NAME:pascal}/styledComponents.spec.js'      : 'styledSpec'
            \   },
            \   'src/test/redux/': {
            \     '{NAME:pascal}/saga.spec.js'                  : 'sagaSpec',
            \     '{NAME:pascal}/reducer.spec.js'               : 'reducerSpec',
            \     '{NAME:pascal}/selector.spec.js'              : 'selectorSpec',
            \     '{NAME:pascal}/api.spec.js'                   : 'apiSpec',
            \     '{NAME:pascal}/action.spec.js'                : 'actionSpec'
            \   },
            \   'src/test/fixtures/{NAME:camel}/{NAME:camel}.js': 'fixtures'
            \ }
```

## Recommandation
Since configuration are project specific, I'd advice to either:
- Add mapping to your repo `.vimrc` and to activate `set exrc`
- Create a `vimrc` file not tracked by your VCS, and source it manually, e.g.:
   ```vim
    " In ~/Repo/.git/vimrc
    let g:CartographeMap = {}

    " in ~/.vimrc
    if filereadable(getcwd() . '/.git/vimrc')
        execute 'source' getcwd() . '/.git/vimrc'
    endif
   ```
