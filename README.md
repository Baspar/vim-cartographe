# vim-cartographe

Vim Cartographe is a plugin aiming at simplifying the navigation in a project.
Given a configuration, you'll be able to jump between file whose path is defined by common variables.

You may want to install FZF as a plugin to enable FZF splits.

## Installation

I recommend using [vim-plug](https://github.com/junegunn/vim-plug) as a plugin manager.
From there, simply add
```vim
Plug 'baspar/vim-cartographe'
```
to your plugin list

## Usage

### Configuration
The configuration is a nested dictionary which key can be folder (ending with `/`, or files).

Values can be a file type, or nested dictionary, which will be interpreted as a nested path.
Cartographe is going to try to fill up intermediate paths if needed.
For example:
```vim
{
\   'src/main/': {
\     '{NAME:pascal}/{NAME:camel}.js': 'index'
\   },
\   'src/test/': {
\     '{NAME:pascal}/{NAME:camel}.js': 'indexSpec'
\   }
\ }
```

Will match the files `src/main/components/Layout/layout.js`, and `src/tests/components/Layout/layout.spec.js`, and you'll be able to navigate between them, despite the `components` folder not mentionned in the configuration

Variables can be specified following the format `{NAME}` or `{NAME:format}`, and the available format are:
- `pascal` for PascalCase
- `camel` for camelCase
- `snake` for SNAKE_CASE
- `kebab` for kebab-case



### Example configuration
```vim
let g:CartographeMap =
            \ {
            \   'src/main/components/': {
            \     '{NAME:pascal}/index.js'                       : 'index',
            \     '{NAME:pascal}/stories.js'                     : 'stories',
            \     '{NAME:pascal}/{NAME:pascal}.js'               : 'pure',
            \     '{NAME:pascal}/styledComponents.js'            : 'styled'
            \   },
            \   'src/main/redux/': {
            \     '{NAME:pascal}/saga.js'                        : 'saga',
            \     '{NAME:pascal}/reducer.js'                     : 'reducer',
            \     '{NAME:pascal}/selector.js'                    : 'selector',
            \     '{NAME:pascal}/api.js'                         : 'api',
            \     '{NAME:pascal}/action.js'                      : 'action'
            \   },
            \   'src/test/components/': {
            \     '{NAME:pascal}/index.spec.js'                  : 'indexSpec',
            \     '{NAME:pascal}/{NAME:pascal}.spec.js'          : 'pureSpec',
            \     '{NAME:pascal}/styledComponents.spec.js'       : 'styledSpec'
            \   },
            \   'src/test/redux/': {
            \     '{NAME:pascal}/saga.spec.js'                   : 'sagaSpec',
            \     '{NAME:pascal}/reducer.spec.js'                : 'reducerSpec',
            \     '{NAME:pascal}/selector.spec.js'               : 'selectorSpec',
            \     '{NAME:pascal}/api.spec.js'                    : 'apiSpec',
            \     '{NAME:pascal}/action.spec.js'                 : 'actionSpec'
            \   },
            \   'src/test/fixtures/{NAME:camel}/{NAME:camel}.js' : 'fixtures'
            \ }
```

### Commands
- `:CartographeNav`
Will open a FZF window with the list of all files. They'll appear in in white if existing, and in grey if they do not exist yet.

You select multiple file with `tab`, open them with `enter`, `<C-x>` or `<C-v>` (Vertical and horizontal split)

- `:CartographeNav pureSpec`
Will open the file of type `pureSpec` in the current window

- `:CartographeNavS pureSpec` & `:CartographeNavV pureSpec`
Will open the file of type `pureSpec` in a vertical/horizontal split

- `:CartographeExec !npm run test {NAME:pascal}`
Will run the given command after injecting file variables


## Recommandation
Since configuration are project specific, you should either:
- Add the configration to your repo `.vimrc` and to activate `set exrc`
- Create a `vimrc` file not tracked by your VCS, and source it manually, e.g.:
   ```vim
    " In ~/Repo/.git/vimrc
    let g:CartographeMap = {}

    " in ~/.vimrc
    if filereadable(getcwd() . '/.git/vimrc')
        execute 'source' getcwd() . '/.git/vimrc'
    endif
   ```

