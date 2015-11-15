{BufferedProcess} = require 'atom'
AtomPHPCSStatusView = require './atom-phpcs-status-view'

module.exports = AtomPHPCS =
    classes: ['atom-phpcs-error', 'atom-phpcs-warning']

    config:
        standard:
            type: 'string'
            default: 'PEAR'
        path:
            type: 'string'
            default: 'phpcs'

    editor: null

    filepath: null

    cserrors: {}

    markers: {}

    statusBarTile: null

    codesniff: () ->
        editor = atom.workspace.getActiveTextEditor();
        if typeof editor == 'object'
            path = editor.getPath();
            if typeof path != 'undefined'
                if path.match('\.php$|\.inc$') isnt false
                    @generateErrors();

    activate: () ->
        @statusBarTile = new AtomPHPCSStatusView()
        @statusBarTile.initialize()
        editor   = atom.workspace.getActiveTextEditor()
        @markers = {}
        @cserrors = {}
        @filepath = null
        eventCb = (event) ->
            AtomPHPCS.codesniff()
        cursorCb = (event) ->
            lineNo = (event.newScreenPosition.row + 1)
            errorLine = AtomPHPCS.cserrors[AtomPHPCS.filepath][lineNo] ? {}
            message = ''
            if errorLine['message']?
                console.log errorLine['message']
                message = errorLine['message'].replace('\\', '').replace(/^"/, '').replace(/"$/, '')

            AtomPHPCS.updateStatus(message)

        editor.onDidSave(eventCb)
        editor.onDidChange(eventCb)
        editor.onDidChangePath(eventCb)
        editor.onDidChangeCursorPosition(cursorCb)

        AtomPHPCS.codesniff()

    consumeStatusBar: (statusBar) ->
        statusBar.addLeftTile(item: AtomPHPCS.statusBarTile, priority: 100)

    deactivate: ->
        AtomPHPCS.statusBarTile?.destroy()
        AtomPHPCS.statusBarTile = null

    sniffFile: (@filepath, callback) ->
      command    = atom.config.get('atom-phpcs.path');
      standard   = atom.config.get('atom-phpcs.standard');
      directory  = filepath.replace(/\\/g, '/').replace(/\/[^\/]*$/, '')
      output     = []
      errorLines = []

      args = ["-n", "--report=csv", "--standard="+standard, filepath]

      options = {cwd: directory}

      stdout = (cs_output) ->
        output = cs_output.replace("\r", "").split("\n")

      stderr = (cs_error) ->
        errorLines = cs_error.replace("\r", "").split("\n")

      exit = (code) =>
        if code is 2
            atom.confirm
                message: "Cannot open file"
                detailedMessage: errorLines.join('\n')
                buttons: ['OK']
        else
            clean = []
            output.shift()
            for i, line of output
                if typeof line is 'undefined'
                    delete output[i]
                else
                    line = line.split(',')
                    if typeof line != 'undefined'
                        [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = line
                        clean[lineNo] = {
                            file: file,
                            lineNo: lineNo,
                            column: column,
                            errorType: errorType,
                            message: errorMessage
                        }

            AtomPHPCS.cserrors[AtomPHPCS.filepath] = clean
            if typeof callback is 'function'
                callback.call()

      new BufferedProcess({command, args, options, stdout, stderr, exit})

    moveToNextError: () ->
        cursorLineNumber = @editor.getCursorBufferPosition().row + 1
        nextErrorLineNumber = null
        firstErrorLineNumber = null
        hunks = AtomPHPCS.cserrors[AtomPHPCS.editor.getPath()] ? []
        for {errorLine} in hunks
            [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = errorLine
            if lineNo > cursorLineNumber
                nextErrorLineNumber ?= lineNo - 1
                nextErrorLineNumber = Math.min(lineNo - 1, nextErrorLineNumber)

            firstErrorLineNumber ?= lineNo - 1
            firstErrorLineNumber = Math.min(lineNo - 1, firstErrorLineNumber)

        # Wrap around to the first error in the file
        nextErrorLineNumber = firstErrorLineNumber unless nextErrorLineNumber?

        AtomPHPCS.moveToLineNumber(nextErrorLineNumber)

    moveToPreviousError: () ->
        cursorLineNumber = AtomPHPCS.editor.getCursorBufferPosition().row + 1
        previousErrorLineNumber = -1
        lastErrorLineNumber = -1
        hunks = AtomPHPCS.cserrors[AtomPHPCS.editor.getPath()] ? []
        for {errorLine} in hunks
            [file, lineNo, column, errorType, errorMessage, errorCat, errorFlag] = errorLine
            if lineNo < cursorLineNumber
                previousErrorLineNumber = Math.max(lineNo - 1, previousErrorLineNumber)
            lastErrorLineNumber = Math.max(lineNo - 1, lastErrorLineNumber)

        # Wrap around to the last error in the file
        previousErrorLineNumber = lastErrorLineNumber if previousErrorLineNumber is -1

        AtomPHPCS.moveToLineNumber(previousErrorLineNumber)

    moveToLineNumber: (lineNumber=-1) ->
        if lineNumber >= 0
            AtomPHPCS.editor.setCursorBufferPosition([lineNumber, 0])
            AtomPHPCS.editor.moveCursorToFirstCharacterOfLine()

    generateErrors: () ->
        editor   = atom.workspace.getActiveTextEditor()
        filepath = editor.getPath()
        AtomPHPCS.sniffFile(filepath, @renderErrors);

    addError: (startRow, endRow, message, highlight) ->
        editor     = atom.workspace.getActiveTextEditor()
        marker     = editor.markBufferRange([[startRow, 0], [endRow, 0]], invalidate: 'never')
        decoration = editor.decorateMarker(marker, {type: 'line-number', class: highlight})
        AtomPHPCS.markers.push(marker)

    removeErrors: ->
        for marker in AtomPHPCS.markers
            marker.destroy()
            marker = null
        AtomPHPCS.markers = []

    renderErrors: () ->
        AtomPHPCS.removeErrors()
        hunks            = AtomPHPCS.cserrors[AtomPHPCS.filepath] ? []
        linesHighlighted = false
        if hunks.length > 0
            for lineNo, errorLine of hunks
                if errorLine['errorType'] is 'error'
                    AtomPHPCS.addError(lineNo-1, lineNo-1, errorLine['message'], 'atom-phpcs-error')
                else if errorLine['errorType'] is 'warning'
                    AtomPHPCS.addError(lineNo-1, lineNo-1, errorLine['message'], 'atom-phpcs-warning')

    updateStatus: (message) ->
        AtomPHPCS.statusBarTile.updateStatusBar(message)
