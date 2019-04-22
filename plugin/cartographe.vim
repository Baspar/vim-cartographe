" Helpers
func! s:Eq(a, b)
    return type(a:a) == type(a:b) && a:a == a:b
endfunc

" Error Handling
func! s:Error(err)
    return { 'Error': a:err }
endfunc

func! s:HasError(res)
    return type(a:res) == type({}) && has_key(a:res, 'Error')
endfunc

" CartographeMap helper
func! s:CartographeMapFlatten()
    if exists('g:CartographeFlattenMap')
        return g:CartographeFlattenMap
    endif

    let flattenMap = {}

    if exists('g:CartographeMap.root') && type(g:CartographeMap.root) == type('')
        let entry = deepcopy(g:CartographeMap)
        let locations = entry['locations']
        unlet entry['locations']
        for [locationname, location] in items(locations)
            let key = locationname
            let value = deepcopy(entry)
            let variables = s:ReadVariables(location)
            let value['location'] = substitute(location, '\(^/\|/$\)', '', 'g')
            let value['variables'] = variables
            let value['root'] = substitute(value['root'], '\(^/\|/$\)', '', 'g')
            let flattenMap[key] = value
        endfor
    else
        for [category, entry] in items(deepcopy(g:CartographeMap))
            let locations = entry['locations']
            unlet entry['locations']
            for [locationname, location] in items(locations)
                let key = category . '.' . locationname
                let value = deepcopy(entry)
                let variables = s:ReadVariables(location)
                let value['location'] = substitute(location, '\(^/\|/$\)', '', 'g')
                let value['variables'] = variables
                let value['root'] = substitute(value['root'], '\(^/\|/$\)', '', 'g')
                let flattenMap[key] = value
            endfor
        endfor
    endif
    let g:CartographeFlattenMap = flattenMap
    return flattenMap
endfunc

" Modifier handling
func! s:FormatWithModifier(name, modifier)
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

func! s:UnformatWithModifier(name, modifier)
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
func! s:CheckExtractedVariables(variables)
    let info = a:variables.info
    let values = a:variables.values

    " Cannot match pattern
    if len(values) == 0
        return s:Error('Cannot match')
    endif

    " Cannot match all variables
    for i in range(len(info))
        if s:Eq(values[i], '')
            return s:Error('Cannot match')
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
            let variable_value = s:UnformatWithModifier(variable_value, variable_modifier[0])
        endif

        " Variable already seen
        if has_key(mem_variables, variable_name)
            " All or none should have a modifier
            if mem_variables[variable_name].has_modifier != has_modifier
                return s:Error('Cannot match')
            endif

            " Value doesn't match modifier
            if mem_variables[variable_name].value != variable_value
                return s:Error('Cannot match')
            endif
        endif
        let mem_variables[variable_name] = {
                    \ 'value': variable_value,
                    \ 'has_modifier': len(variable_modifier) > 0
                    \ }
    endfor

    return mem_variables
endfunc

func! s:ReadVariables(pattern)
    let variables_info = []
    call substitute(a:pattern, '{\zs[a-zA-Z]*\%(:[a-zA-Z]\+\)\?\ze}', '\=add(variables_info, submatch(0))', 'g')
    let variables_info = map(variables_info, {id, name -> {
                \ 'name': split(name, ':')[0],
                \ 'modifier': split(name, ':')[1:],
                \ 'has_modifier': len(split(name, ':')) > 1
                \ }})
    return variables_info
endfunc!

func! s:ExtractVariables(string_to_match, pattern)
    let variables_values = matchlist(a:string_to_match, substitute(a:pattern."$", "{[^}]*}", "\\\\([^/]*\\\\)", "g"))[1:]
    let variables_info = s:ReadVariables(a:pattern)

    return {
                \ 'info': variables_info,
                \ 'values': variables_values
                \ }
endfunc

func! s:InjectVariables(type_settings, variables)
    let string_with_variables = a:type_settings['location']
    let variables_info = s:ReadVariables(string_with_variables)
    for variable_info in variables_info
        let variable_name = variable_info['name']
        let variable_modifier = variable_info['modifier']
        let variable_value = a:variables[variable_name]['value']
        let variable_has_modifier = a:variables[variable_name]['has_modifier']
        if variable_has_modifier
            let variable_value = s:FormatWithModifier(variable_value, variable_modifier[0])
        endif
        let string_with_variables = substitute(string_with_variables, '{'.variable_name.'\%(:[a-zA-Z]\+\)\?}', variable_value, '')
    endfor
    return string_with_variables
endfunc!


func! s:ExtractRoot(root, file_path, pattern)
    let matches = matchlist(a:file_path, substitute('^\(.*\)'.a:root.'\(.*/\)'.a:pattern."$", "{[^}]*}", "[^/]\\\\+", "g"))

    if len(matches) == 0
        return s:Error('Cannot extract root')
    endif
    return matches[1:2]
endfunc

func! s:FindCurrentFileInfo(settings)
    if exists('b:CartographeBufferInfo')
        return b:CartographeBufferInfo
    endif

    let file_path = expand("%:p")

    for [type, info] in items(a:settings)
        let root = info['root']

        let pattern = info['location']
        let variables_info = s:ExtractVariables(file_path, pattern)
        let checked_variables = s:CheckExtractedVariables(variables_info)
        let roots = s:ExtractRoot(root, file_path, pattern)
        if !s:HasError(checked_variables) && !s:HasError(roots)
            let [absolute_root, intermediate_root] = roots
            let checked_variables['type'] = type
            let info = {
                        \ 'variables': checked_variables,
                        \ 'intermediate_root': intermediate_root,
                        \ 'absolute_root': absolute_root,
                        \ 'type': type
                        \ }
            let b:CartographeBufferInfo = info
            return info
        endif
    endfor

    return s:Error('Cannot find a type')
endfunc

func! s:OpenFZF(settings, current_file_info)
    let variables = a:current_file_info['variables']
    let absolute_root = a:current_file_info['absolute_root']
    let intermediate_root = a:current_file_info['intermediate_root']

    let existing_matched_types = []
    let new_matched_types = []
    for [type, type_settings] in items(a:settings)
        let path = s:InjectVariables(type_settings, variables)
        let root = type_settings['root']
        if filereadable(absolute_root . root . intermediate_root . path)
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
            call s:CartographeNavigate(type, command)
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
func! s:CartographeComplete(A,L,P)
    let settings = s:CartographeMapFlatten()
    let partial_argument = substitute(a:L, '^\S\+\s\+', '', '')
    let potential_completion = copy(keys(settings))
    return filter(potential_completion, {idx, val -> val =~ "^".partial_argument})
endfun

" Main functions
func! s:CartographeNavigate(type, command)
    if !exists("g:CartographeMap")
        echohl WarningMsg
        echom "[Cartographe] Please define your g:CartographeMap"
        echohl None
        return
    endif

    let settings = s:CartographeMapFlatten()

    let current_file_info = s:FindCurrentFileInfo(settings)

    if s:HasError(current_file_info)
        echohl WarningMsg
        echom "[Cartographe] Cannot match current file with any type"
        echohl None
        return
    endif

    if a:type == ''
        call s:OpenFZF(settings, current_file_info)
    else
        if !has_key(settings, a:type)
            echohl WarningMsg
            echom "[Cartographe] Cannot find information for type '" . a:type . "'"
            echohl None
            return
        endif

        let root = settings[a:type]['root']
        let variables = current_file_info['variables']
        let intermediate_root = current_file_info['intermediate_root']
        let absolute_root = current_file_info['absolute_root']

        let new_path = s:InjectVariables(settings[a:type], variables)

        if filereadable(root . intermediate_root . new_path)
            execute a:command absolute_root . root . intermediate_root . new_path
        else
            execute a:command absolute_root . root . intermediate_root . new_path
        endif
    endif
endfunc

func! s:CartographeListComponents(type)
    if !exists("g:CartographeMap")
        echohl WarningMsg
        echom "[Cartographe] Please define your g:CartographeMap"
        echohl None
        return
    endif

    let settings = s:CartographeMapFlatten()

    if !has_key(settings, a:type)
        echoerr "[Cartographe] Cannot find type '".a:type."' in your g:CartographeMap"
        return
    endif

    let pattern = settings[a:type]['location']
    let root = settings[a:type]['root']
    let files = globpath('.', root.'/**/'.substitute(pattern, "{[^}]*}", "*", 'g'))


    let valid_files = []
    for file in split(files, '\n')
        let infos = s:CheckExtractedVariables(s:ExtractVariables(file, pattern))
        if s:HasError(infos)
            continue
        endif

        call add(valid_files, file)

        " TODO: handle no modifier
        " echo infos
        " let fancy_name = s:InjectVariables("{name:camel}", infos)
        " if !has_key(fancy_names, fancy_name)
        "     let fancy_names[fancy_name] = {}
        " endif
        " let fancy_names[fancy_name] = { 'file': file }
    endfor

    func! Handle_sink_bis(list)
        let command = get({
                    \ 'ctrl-x': 'split',
                    \ 'ctrl-v': 'vsplit',
                    \ }, a:list[0], 'edit')

        for file in a:list[1:]
            execute command file
        endfor
    endfunc

    call fzf#run({
                \ 'source': valid_files,
                \ 'options': '--no-sort --multi --expect=ctrl-v,ctrl-x',
                \ 'down': "25%",
                \ 'sink*': {a -> Handle_sink_bis(a)}
                \ })
endfunc

nnoremap <leader><leader>g :CartographeNav<CR>

command! -nargs=1 -complete=customlist,s:CartographeComplete CartographeComp call s:CartographeListComponents('<args>')
command! -nargs=? -complete=customlist,s:CartographeComplete CartographeNav  call s:CartographeNavigate('<args>', 'edit')
command! -nargs=? -complete=customlist,s:CartographeComplete CartographeNavS call s:CartographeNavigate('<args>', 'split')
command! -nargs=? -complete=customlist,s:CartographeComplete CartographeNavV call s:CartographeNavigate('<args>', 'vsplit')
