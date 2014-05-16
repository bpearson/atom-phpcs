{$, BufferedProcess} = require 'atom'

module.exports =
class AtomPHPCSView

  classes: ['atom-phpcs-error', 'atom-phpcs-warning']

  constructor: (@editorView) ->
    @editor   = @editorView.editor
    @gutter   = @editorView.gutter
    @cserrors = {}

    @editorView.command 'core:save', =>
      @updateErrors()
    @editorView.command 'editor:path-changed', =>
      @updateErrors()
    @editorView.command 'editor:display-updated', =>
      @renderErrors()

    @editorView.command 'atom-phpcs:codesniff', =>
      @updateErrors()

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

  updateErrors: ->
    @generateErrors(@renderErrors)

  generateErrors: (callback)->
    editor     = atom.workspace.getActiveEditor()
    filepath   = editor.getPath()
    directory  = filepath.replace(/\\/g, '/').replace(/\/[^\/]*$/, '')
    output     = []
    errorLines = []
    new BufferedProcess({
      command: '/usr/bin/phpcs'
      args: ["-n", "--report=csv", "--standard=Squiz", filepath]
      options: {
        cwd: directory
      }
      stdout: (cs_output) =>
        output = cs_output.split('\n')
      stderr: (cs_error) =>
        errorLines = cs_error.split('\n')
      exit: (code) =>
        if code is 2
          atom.confirm
            message: "Cannot open file"
            detailedMessage: errorLines.join('\n')
            buttons: ['OK']
        else
          clean = []
          output.shift()
          lines = for i, line of output
            if typeof line is 'undefined'
              delete output[i]
            else
              clean.push(line.split(','))
          @cserrors[filepath] = clean
          callback.call()
    })


  removeErrors: =>
    if @gutter.hasErrorLines
      @gutter.removeClassFromAllLines(cssClass) for cssClass in @classes
      @gutter.hasErrorLines = false

  renderErrors: =>
    return unless @gutter.isVisible()

    @removeErrors()

    hunks            = @cserrors[@editor.getPath()] ? []
    linesHighlighted = false
    if hunks.length > 0
      for errorLineNo, errorLine of hunks
        if typeof errorLine isnt 'undefined'
          [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = errorLine
          if errorType is 'error'
            linesHighlighted |= @gutter.addClassToLine(lineNo - 1, 'atom-phpcs-error')
          else if errorType is 'warning'
            linesHighlighted |= @gutter.addClassToLine(lineNo - 1, 'atom-phpcs-warning')

    @gutter.hasErrorLines = linesHighlighted
