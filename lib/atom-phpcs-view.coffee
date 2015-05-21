{BufferedProcess} = require 'atom'

module.exports =
class AtomPHPCSView

  classes: ['atom-phpcs-error', 'atom-phpcs-warning']

  constructor: () ->
    @editor   = atom.workspace.getActiveTextEditor()
    @cserrors = {}
    @filepath = null

    editorView.onDidSave(@updateErrors(@generateErrors))

    editorView.onDidChange(@updateErrors(@generateErrors))

    editorView.onDidChangePath(@updateErrors(@generateErrors))

  moveToNextError: ->
    cursorLineNumber = @editor.getCursorBufferPosition().row + 1
    nextErrorLineNumber = null
    firstErrorLineNumber = null
    hunks = @cserrors[@editor.getPath()] ? []
    for {errorLine} in hunks
      [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = errorLine
      if lineNo > cursorLineNumber
        nextErrorLineNumber ?= lineNo - 1
        nextErrorLineNumber = Math.min(lineNo - 1, nextErrorLineNumber)

      firstErrorLineNumber ?= lineNo - 1
      firstErrorLineNumber = Math.min(lineNo - 1, firstErrorLineNumber)

    # Wrap around to the first error in the file
    nextErrorLineNumber = firstErrorLineNumber unless nextErrorLineNumber?

    @moveToLineNumber(nextErrorLineNumber)

  moveToPreviousError: ->
    cursorLineNumber = @editor.getCursorBufferPosition().row + 1
    previousErrorLineNumber = -1
    lastErrorLineNumber = -1
    hunks = @cserrors[@editor.getPath()] ? []
    for {errorLine} in hunks
      [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = errorLine
      if lineNo < cursorLineNumber
        previousErrorLineNumber = Math.max(lineNo - 1, previousErrorLineNumber)
      lastErrorLineNumber = Math.max(lineNo - 1, lastErrorLineNumber)

    # Wrap around to the last error in the file
    previousErrorLineNumber = lastErrorLineNumber if previousErrorLineNumber is -1

    @moveToLineNumber(previousErrorLineNumber)

  moveToLineNumber: (lineNumber=-1) ->
    if lineNumber >= 0
      @editor.setCursorBufferPosition([lineNumber, 0])
      @editor.moveCursorToFirstCharacterOfLine()

  generateErrors: () ->
    editor     = atom.workspace.getActiveTextEditor()
    filepath   = editor.getPath()
    AtomPHPCS.sniffFile filepath, @renderErrors

  addError: (range, highlight) ->
    editor     = atom.workspace.getActiveTextEditor()
    marker     = editor.markBufferRange(range)
    decoration = editor.decorateMarker(marker, {type: 'line', class: highlight})
    @markers.push marker

  removeErrors: =>
    for marker in @markers
      marker.destroy()
      marker = null
    @markers = []

  renderErrors: =>
    @removeErrors()

    hunks            = @cserrors[@editor.getPath()] ? []
    linesHighlighted = false
    if hunks.length > 0
      for errorLineNo, errorLine of hunks
        if typeof errorLine isnt 'undefined'
          [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = errorLine
          range = new Range([lineNo, column], [lineNo, (column + 1)])
          if errorType is 'error'
            @addError(range, 'atom-phpcs-error')
          else if errorType is 'warning'
            @addError(range, 'atom-phpcs-warning')

  updateErrors: (callback) ->
    callback.call()
