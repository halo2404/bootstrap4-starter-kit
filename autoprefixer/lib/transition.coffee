parser = require('postcss-value-parser')
vendor = require('postcss/lib/vendor')

class Transition
  constructor: (@prefixes) ->

  # Properties to be processed
  props: ['transition', 'transition-property']

  # Process transition and add prefies for all necessary properties
  add: (decl, result) ->
    declPrefixes = @prefixes.add[decl.prop]?.prefixes || []

    params = @parse(decl.value)
    names  = params.map (i) -> i[0].value
    added  = []

    return if names.some (i) -> i[0] == '-'

    for param in params
      prop = param[0].value
      continue if prop[0] == '-'
      prefixer = @prefixes.add[prop]
      continue if not prefixer?.prefixes

      for prefix in prefixer.prefixes
        prefixed = @prefixes.prefixed(prop, prefix)
        if prefixed != '-ms-transform' and names.indexOf(prefixed) == -1
          added.push(@clone(prefixed, param))

    params = params.concat(added)
    value  = @stringify(params)

    clean = @stringify(@cleanForSafari(params))
    if declPrefixes.indexOf('-webkit-') != -1
      @cloneBefore(decl, '-webkit-' + decl.prop, clean)
    @cloneBefore(decl, decl.prop, clean)

    for prefix in declPrefixes
      if prefix != '-webkit-'
        prefixValue = @stringify(@cleanOtherPrefixes(params, prefix))
        @cloneBefore(decl, prefix + decl.prop, prefixValue)

    if value != decl.value and not @already(decl, decl.prop, value)
      @checkForWarning(result, decl)
      decl.cloneBefore()
      decl.value = value

  # Does we aready have this declaration
  already: (decl, prop, value) ->
    decl.parent.some (i) -> i.prop == prop and i.value == value

  # Add declaration if it is not exist
  cloneBefore: (decl, prop, value) ->
    unless @already(decl, prop, value)
      decl.cloneBefore(prop: prop, value: value)

  # Show transition-property warning
  checkForWarning: (result, decl) ->
    if decl.prop == 'transition-property'
      decl.parent.each (i) ->
        return if i.type != 'decl'
        return if i.prop.indexOf('transition-') != 0
        return if i.prop == 'transition-property'

        if i.value.indexOf(',') != -1
          decl.warn(result, 'Replace transition-property to transition, ' +
                            'because Autoprefixer could not support ' +
                            'any cases of transition-property ' +
                            'and other transition-*')
        return false

  # Process transition and remove all unnecessary properties
  remove: (decl) ->
    params = @parse(decl.value)
    params = params.filter (param) => !@prefixes.remove[param[0].value]?.remove
    value  = @stringify(params)

    return if decl.value == value

    if params.length == 0
      decl.remove();
      return

    double  = decl.parent.some (i) -> i.prop == decl.prop and i.value == value
    smaller = decl.parent.some (i) ->
      i != decl and i.prop == decl.prop and i.value.length > value.length

    if double or smaller
      decl.remove()
    else
      decl.value = value

  # Parse properties list to array
  parse: (value) ->
    ast    = parser(value)
    result = []
    param  = []
    for node in ast.nodes
      param.push(node)
      if node.type == 'div' and node.value == ','
        result.push(param)
        param = []
    result.push(param)
    result.filter (i) -> i.length > 0

  # Return properties string from array
  stringify: (params) ->
    return '' if params.length == 0
    nodes = []
    for param in params
      if param[param.length - 1].type != 'div'
        param.push(@div(params))
      nodes = nodes.concat(param)
    if nodes[0].type == 'div'
      nodes = nodes[1..-1]
    if nodes[nodes.length - 1].type == 'div'
      nodes = nodes[0..-2]
    parser.stringify({ nodes: nodes })

  # Return new param array with different name
  clone: (name, param) ->
    result = []
    for i in param
      result.push(i)
    result[0] = { type: 'word', value: name }
    result

  # Find or create seperator
  div: (params) ->
    for param in params
      for node in param
        if node.type == 'div' and node.value == ','
          return node
    { type: 'div', value: ',', after: ' ' }

  cleanOtherPrefixes: (params, prefix) ->
    params.filter (param) ->
      current = vendor.prefix(param[0].value)
      current == '' or current == prefix

  # Remove all non-webkit prefixes and unprefixed params if we have prefixed
  cleanForSafari: (params) ->
    result = []
    remove = params
      .map (i) -> i[0].value
      .filter (i) -> i[0..7] == '-webkit-'
      .map (i) => @prefixes.unprefixed(i)
    for param in params
      prop   = param[0].value
      prefix = vendor.prefix(prop)
      if remove.indexOf(prop) == -1 and (prefix == '-webkit-' or prefix == '')
        result.push(param)
    result

module.exports = Transition
