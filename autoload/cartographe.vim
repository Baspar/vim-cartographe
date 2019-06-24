" Helpers
func! cartographe#Eq(a, b)
    return type(a:a) == type(a:b) && a:a == a:b
endfunc

" Error Handling
func! cartographe#Error(err)
    return { 'Error': a:err }
endfunc

func! cartographe#HasError(res)
    return type(a:res) == type({}) && has_key(a:res, 'Error')
endfunc

" CartographeMap flattener
func! cartographe#CartographeMapFlattenRecc(m)
    let flattenMap = {}
    for [path, child] in items(a:m)
        let variables = cartographe#ReadVariables(path)
        if split(path, '\zs')[-1] == '/'
            " Need to recurse
            let formatted_child = cartographe#CartographeMapFlattenRecc(child)
            for [name, child_info] in items(formatted_child)
                let new_path = insert(child_info.path, path)
                let new_variables = variables + child_info.variables
                let flattenMap[name] =
                            \ {
                            \   "path": new_path,
                            \   "variables": new_variables
                            \ }
            endfor
        else
            " Leaf case
            let flattenMap[child] =
                        \ {
                        \   "path": [path],
                        \   "variables": variables
                        \ }
        endif
    endfor
    return flattenMap
endfunc

func! cartographe#CartographeMapFlatten()
    if exists('g:CartographeFlattenMap')
        return g:CartographeFlattenMap
    endif

    return cartographe#CartographeMapFlattenRecc(g:CartographeMap)
endfunc

" Modifier handling
func! cartographe#FormatWithModifier(name, modifier)
    if a:modifier == 'pascal'
        return substitute(
                    \ join(map(a:name, {_,w -> tolower(w)}), '_'),
                    \ '\%(_\|^\)\(\l\)',
                    \ '\U\1',
                    \ 'g'
                    \ )
    elseif a:modifier == 'camel'
        return substitute(
                    \ join(map(a:name, {_,w -> tolower(w)}), '_'),
                    \ '_\(\l\)',
                    \ '\U\1',
                    \ 'g'
                    \ )
    elseif a:modifier == 'snake'
        return join(map(a:name, {_,w -> toupper(w)}), '_')
    elseif a:modifier == 'kebab'
        return join(map(a:name, {_,w -> tolower(w)}), '-')
    else
        return join(a:name, '')
    endif
endfunc

func! cartographe#UnformatWithModifier(name, modifier)
    if a:modifier == 'pascal'
        let splitRes = split(a:name, '\ze[A-Z]')
    elseif a:modifier == 'camel'
        let splitRes = split(a:name, '\ze[A-Z]')
    elseif a:modifier == 'snake'
        let splitRes = split(a:name, '_')
    elseif a:modifier == 'kebab'
        let splitRes = split(a:name, '-')
    else
        let splitRes = [a:name]
    endif
    return map(splitRes, {_, w -> tolower(w)})
endfunc

" Variables manipulation
func! cartographe#CheckExtractedVariables(variables)
    let info = a:variables.info
    let values = a:variables.values

    " Cannot match pattern
    if len(values) == 0
        return cartographe#Error('Cannot match')
    endif

    " Cannot match all variables
    for i in range(len(info))
        if cartographe#Eq(values[i], '')
            return cartographe#Error('Cannot match')
        endif
    endfor

    let mem_variables = {}
    for id in range(len(info))
        let variable_name = info[id].name
        let variable_modifier = info[id].modifier
        let has_modifier = len(variable_modifier) > 0
        let variable_value = values[id]

        " Unformat if variable has modifier
        if has_modifier
            let variable_value = cartographe#UnformatWithModifier(variable_value, variable_modifier[0])
        endif

        " Variable already seen
        if has_key(mem_variables, variable_name)
            " All or none should have a modifier
            if mem_variables[variable_name].has_modifier != has_modifier
                return cartographe#Error('Cannot match')
            endif

            " Value doesn't match modifier
            if mem_variables[variable_name].value != variable_value
                return cartographe#Error('Cannot match')
            endif
        endif
        let mem_variables[variable_name] = {
                    \ 'value': variable_value,
                    \ 'has_modifier': len(variable_modifier) > 0
                    \ }
    endfor

    return mem_variables
endfunc

func! cartographe#ReadVariables(pattern)
    let variables_info = []
    call substitute(a:pattern, '{\zs[a-zA-Z]*\%(:[a-zA-Z]\+\)\?\ze}', '\=add(variables_info, submatch(0))', 'g')
    let variables_info = map(variables_info, {id, name -> {
                \ 'name': split(name, ':')[0],
                \ 'modifier': split(name, ':')[1:],
                \ 'has_modifier': len(split(name, ':')) > 1
                \ }})
    return variables_info
endfunc

func! cartographe#ExtractVariables(string_to_match, pattern)
    let p = substitute(a:pattern."$", "{[^}]*}", "\\\\([^/]\\\\+\\\\)", "g")
    let p = substitute(p, "\\*\\*/", "\\\\%(.*/\\\\)\\\\?", "g")
    let variables_values = matchlist(a:string_to_match, p)[1:]
    let variables_info = cartographe#ReadVariables(a:pattern)

    return {
                \ 'info': variables_info,
                \ 'values': variables_values
                \ }
endfunc

func! cartographe#InjectVariables(path, variables)
    let string_with_variables = a:path
    let variables_info = cartographe#ReadVariables(string_with_variables)
    for variable_info in variables_info
        let variable_name = variable_info['name']
        let variable_modifier = variable_info['modifier']
        let variable_value = a:variables[variable_name]['value']
        let variable_has_modifier = a:variables[variable_name]['has_modifier']
        if variable_has_modifier
            let variable_value = cartographe#FormatWithModifier(variable_value, variable_modifier[0])
        endif
        let string_with_variables = substitute(string_with_variables, '{'.variable_name.'\%(:[a-zA-Z]\+\)\?}', variable_value, '')
    endfor
    return string_with_variables
endfunc

" Roots manipulation
func! cartographe#ExtractRoots(file_path, pattern)
    let p = substitute(a:pattern."$", "{[^}]*}", "[^/]\\\\+", "g")
    let p = substitute(p, "\\*\\*/", "\\\\(.*/\\\\)\\\\?", "g")
    let matches = matchlist(a:file_path, p)

    if len(matches) == 0
        return cartographe#Error('Cannot extract root')
    endif
    return matches[1:]
endfunc

func! cartographe#InjectRoots(raw_path, roots)
    let path = ''
    let i = -1
    for path_part in a:raw_path
        if i != -1
            let path = path . '/'
            let path = path . a:roots[i]
            let path = path . '/'
        endif
        let path = path . path_part
        let i = i + 1
    endfor
    let path = substitute(path, "/\\+", "/", "g")
    return path
endfunc

func! cartographe#FindCurrentFileInfo(settings)
    if exists('b:CartographeBufferInfo')
        return b:CartographeBufferInfo
    endif

    let file_path = expand("%")

    for [type, info] in items(a:settings)
        let path = info.path
        let variables = info.variables

        let formatted_path = substitute(join(path, '/**/'), '/\+', '/', 'g')

        " Variable extraction
        let checked_variables = cartographe#CheckExtractedVariables(cartographe#ExtractVariables(file_path, formatted_path))

        " 'Roots' extraction
        let roots = cartographe#ExtractRoots(file_path, formatted_path)

        " Check
        if !cartographe#HasError(checked_variables) && !cartographe#HasError(roots)
            let checked_variables['type'] = type
            let info = {
                        \ 'variables': checked_variables,
                        \ 'roots': roots,
                        \ 'type': type
                        \ }
            let b:CartographeBufferInfo = info
            return info
        endif
    endfor

    return cartographe#Error('Cannot find a type')
endfunc

func! cartographe#OpenFZF(settings, current_file_info)
    let variables = a:current_file_info['variables']
    let roots = a:current_file_info['roots']

    let existing_matched_types = []
    let new_matched_types = []
    for [type, type_settings] in items(a:settings)
        let path = type_settings.path
        let path = cartographe#InjectRoots(path, roots)
        let path = cartographe#InjectVariables(path, variables)
        if filereadable(path)
            let existing_matched_types = add(existing_matched_types, "\e[0m" . type)
        else
            let new_matched_types = add(new_matched_types, "\e[90m".type)
        endif
    endfor

    let matches_types = existing_matched_types + new_matched_types

    func! FzfSink(list)
        let command = get({
                    \ 'ctrl-x': 'split',
                    \ 'ctrl-v': 'vsplit',
                    \ }, a:list[0], 'edit')
        for type in a:list[1:]
            call cartographe#CartographeNavigate(type, command)
        endfor
    endfunc

    call fzf#run({
                \ 'source': matches_types,
                \ 'options': '--no-sort --ansi --multi --expect=ctrl-v,ctrl-x',
                \ 'down': len(matches_types)+3,
                \ 'sink*': {a -> FzfSink(a)}
                \ })
endfunc

" Auto complete
func! cartographe#CartographeComplete(A,L,P)
    let settings = cartographe#CartographeMapFlatten()
    let partial_argument = substitute(a:L, '^\S\+\s\+', '', '')
    let potential_completion = copy(keys(settings))
    return filter(potential_completion, {idx, val -> val =~ "^".partial_argument})
endfunc

" Main functions
func! cartographe#CartographeNavigate(type, command)
    if !exists("g:CartographeMap")
        echohl WarningMsg
        echom "[Cartographe] Please define your g:CartographeMap"
        echohl None
        return
    endif

    let settings = cartographe#CartographeMapFlatten()

    " Try to identify current file
    let current_file_info = cartographe#FindCurrentFileInfo(settings)
    if cartographe#HasError(current_file_info)
        echohl WarningMsg
        echom "[Cartographe] Cannot match current file with any type"
        echohl None
        return
    endif

    " Open FZF when no type given
    if a:type == ''
        call cartographe#OpenFZF(settings, current_file_info)
        return
    endif

    " Given type isn't defined on the map
    if !has_key(settings, a:type)
        echohl WarningMsg
        echom "[Cartographe] Cannot find information for type '" . a:type . "'"
        echohl None
        return
    endif

    " Inject data into asked type
    let variables = current_file_info['variables']
    let roots = current_file_info['roots']

    let path = settings[a:type].path
    let path = cartographe#InjectRoots(path, roots)
    let path = cartographe#InjectVariables(path, variables)

    execute a:command path
endfunc

func! cartographe#CartographeListComponents(type)
    if !exists("g:CartographeMap")
        echohl WarningMsg
        echom "[Cartographe] Please define your g:CartographeMap"
        echohl None
        return
    endif

    let settings = cartographe#CartographeMapFlatten()

    if !has_key(settings, a:type)
        echoerr "[Cartographe] Cannot find type '".a:type."' in your g:CartographeMap"
        return
    endif

    let pattern = settings[a:type]['location']
    let root = settings[a:type]['root']
    let files = globpath('.', root.'/**/'.substitute(pattern, "{[^}]*}", "*", 'g'))


    let valid_files = []
    let fancy_names = []
    for file in split(files, '\n')
        let infos = cartographe#CheckExtractedVariables(cartographe#ExtractVariables(file, pattern))
        if cartographe#HasError(infos)
            continue
        endif

        let fancy_name = []
        for [variable_name, variable_info] in items(infos)
            if variable_info['has_modifier']
                let variable_value = cartographe#FormatWithModifier(variable_info['value'], 'pascal')
            else
                let variable_value = variable_info['value']
            endif
            if len(keys(infos)) == 1
                call add(fancy_name, variable_value)
            else
                call add(fancy_name, variable_name.': '.variable_value)
            endif
        endfor

        call add(fancy_names, join(fancy_name, ', '))
        call add(valid_files, file)
    endfor

    func! Handle_sink_bis(valid_files, list)
        let command = get({
                    \ 'ctrl-x': 'split',
                    \ 'ctrl-v': 'vsplit',
                    \ }, a:list[0], 'edit')

        for file in a:list[1:]
            let id = split(file, ']\|[')[0]
            execute command a:valid_files[id]
        endfor
    endfunc

    call fzf#run({
                \ 'source': map(fancy_names, {index, item -> '['.index.'] '.item}),
                \ 'options': '--no-sort --multi --expect=ctrl-v,ctrl-x',
                \ 'down': "25%",
                \ 'sink*': {a -> Handle_sink_bis(valid_files, a)}
                \ })
endfunc
