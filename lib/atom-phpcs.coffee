{BufferedProcess} = require 'atom'
{CompositeDisposable} = require 'atom'
{TextEditor} = require 'atom'
{File} = require 'atom'
AtomPHPCSStatusView = require './atom-phpcs-status-view'

module.exports = AtomPHPCS =
  classes: ['atom-phpcs-error', 'atom-phpcs-warning']

  config:
    standard:
      title: "Standard"
      description: "The standard to use eg. PEAR, PSR1"
      type: 'string'
      default: 'PEAR'
    path:
      title: "PHPCS path"
      description: "The path to PHPCS"
      type: 'string'
      default: 'phpcs'
    cbfpath:
      title: "PHPCBF path"
      description: "The path to PHPCBF"
      type: 'string'
      default: 'phpcbf'
    errorsOnly:
      title: "Errors only"
      description: "If selected, only show the errors"
      type: 'boolean'
      default: false

  editor: null

  filepath: null

  cserrors: {}

  markers: {}

  statusBarTile: null

  activate: () ->
    @subscriptions = new CompositeDisposable()
    @statusBarTile = new AtomPHPCSStatusView()
    @statusBarTile.initialize()
    @markers = {}
    @cserrors = {}
    @filepath = null
    configCb = (event) ->
      editors = atom.workspace.getTextEditors()
      for editor in editors
        if typeof editor == 'object'
          path = editor.getPath()
          if typeof path != 'undefined'
            if path.match('\.php$|\.inc$') isnt false
              AtomPHPCS.generateErrors(editor)
    workspaceCb = (event) ->
      editor = event.TextEditor
      AtomPHPCS.activateEditor(editor)
    atom.config.onDidChange(configCb)
    atom.workspace.onDidAddTextEditor(workspaceCb)
    atom.workspace.observeActivePaneItem(AtomPHPCS.activateEditor)

    @subscriptions.add atom.commands.add 'atom-text-editor',
      'atom-phpcs:codesniff': (event) ->
        AtomPHPCS.codesniff()
      'atom-phpcs:codefixer': (event) ->
        AtomPHPCS.codefixer()

    AtomPHPCS.activateEditors()

  activateEditors: () ->
    editors = atom.workspace.getTextEditors()
    for editor in editors
      if typeof editor == 'object'
        AtomPHPCS.activateEditor(editor)

  activateEditor: (editor) ->
    if (editor instanceof TextEditor)
      eventCb = (event) ->
        AtomPHPCS.codesniff()
      cursorCb = (event) ->
        path   = AtomPHPCS.filepath
        lineNo = (event.newScreenPosition.row + 1)
        AtomPHPCS.showErrorMessage(path, lineNo)
      editor.onDidSave(eventCb)
      editor.onDidChangePath(eventCb)
      editor.onDidChangeCursorPosition(cursorCb)

      AtomPHPCS.codesniff()

  consumeStatusBar: (statusBar) ->
    statusBar.addLeftTile(item: AtomPHPCS.statusBarTile, priority: 100)

  deactivate: ->
    AtomPHPCS.statusBarTile?.destroy()
    AtomPHPCS.statusBarTile = null

  codesniff: () ->
    editor = atom.workspace.getActiveTextEditor()
    if typeof editor == 'object'
      path = editor.getPath()
      if typeof path != 'undefined'
        if path.match('\.php$|\.inc$') isnt false
          @generateErrors(editor)

  codefixer: () ->
    editor = atom.workspace.getActiveTextEditor()
    if typeof editor == 'object'
      path = editor.getPath()
      if typeof path != 'undefined'
        if path.match('\.php$|\.inc$') isnt false
          fixerCb = (message) ->
            AtomPHPCS.updateStatus(message)
            atom.workspace.open(path, [])
            AtomPHPCS.codesniff()
          AtomPHPCS.fixFile(path, editor, fixerCb)

  fixFile: (@filepath, @editor, callback) ->
    AtomPHPCS.removeErrors()
    AtomPHPCS.cserrors = {}
    command    = atom.config.get('atom-phpcs.cbfpath')
    standard   = atom.config.get('atom-phpcs.standard')
    directory  = @filepath.replace(/\\/g, '/').replace(/\/[^\/]*$/, '')
    output     = []
    errorLines = []

    args = ["--standard="+standard, @filepath]
    if atom.config.get('atom-phpcs.errorsOnly') == true
      args.unshift("-n")

    options = {cwd: directory}

    stdout = (cs_output) ->
      output = cs_output.replace("\r", "").split("\n")

    stderr = (cs_error) ->
      errorLines = cs_error.replace("\r", "").split("\n")

    exit = (code) ->
      message = ""
      if code is 2
        console.log 'PHPCBF is setup incorrectly'
      else if code is 1
        message = "Patched 1 file"
      else
        message = "No fixable errors found"

      if typeof callback is 'function'
        callback.call(message)

    phpcsFile = new File(command)
    if command == 'phpcbf' || phpcsFile.existsSync() is true
      new BufferedProcess({command, args, options, stdout, stderr, exit})
    else
      console.log 'PHPCBF is setup incorrectly'

  sniffFile: (@filepath, @editor, callback) ->
    command    = atom.config.get('atom-phpcs.path')
    standard   = atom.config.get('atom-phpcs.standard')
    directory  = @filepath.replace(/\\/g, '/').replace(/\/[^\/]*$/, '')
    output     = []
    errorLines = []

    args = ["--report=json", "--standard="+standard, @filepath]
    if atom.config.get('atom-phpcs.errorsOnly') is true
      args.unshift("-n")

    options = {cwd: directory}

    stdout = (cs_output) ->
      output = cs_output.replace("\r", "").split("\n")

    stderr = (cs_error) ->
      errorLines = cs_error.replace("\r", "").split("\n")

    exit = (code) ->
      if code is 1
        clean = []
        for i, line of output
          if typeof line is 'undefined'
            delete output[i]
          else
            report = JSON.parse(line)
            if report['files'][AtomPHPCS.filepath]['messages']
              for j, message of report['files'][AtomPHPCS.filepath]['messages']
                clean[message['line']] = {
                  file: AtomPHPCS.filepath,
                  lineNo: message['line'],
                  column: message['column'],
                  errorType: message['type'],
                  message: message['message']
                }

        AtomPHPCS.cserrors[AtomPHPCS.filepath] = clean
        if typeof callback is 'function'
          callback.call()
      else
        if code is 2
          console.log 'PHPCS is setup incorrectly'


    phpcsFile = new File(command)
    if command == 'phpcs' || phpcsFile.existsSync() is true
      new BufferedProcess({command, args, options, stdout, stderr, exit})
    else
      console.log 'PHPCS is setup incorrectly'

  showErrorMessage: (path, lineNo) ->
    message = ''
    if AtomPHPCS.cserrors[path]?
      if AtomPHPCS.cserrors[path][lineNo]?
        errorLine = AtomPHPCS.cserrors[path][lineNo] ? {}
        if errorLine['message']?
          message = errorLine['message'].replace(/\\/g, '').replace(/^"/, '').replace(/"$/, '')

    AtomPHPCS.updateStatus(message)

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

  generateErrors: (editor) ->
    filepath = editor.getPath()
    AtomPHPCS.sniffFile(filepath, editor, @renderErrors)

  addError: (editor, startRow, endRow, message, highlight) ->
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
        if errorLine['errorType'] is 'ERROR'
          AtomPHPCS.addError(AtomPHPCS.editor, lineNo-1, lineNo-1, errorLine['message'], 'atom-phpcs-error')
        else if errorLine['errorType'] is 'WARNING'
          AtomPHPCS.addError(AtomPHPCS.editor, lineNo-1, lineNo-1, errorLine['message'], 'atom-phpcs-warning')
    currentEditor = atom.workspace.getActiveTextEditor()
    if currentEditor?
      path   = currentEditor.getPath()
      lineNo = (currentEditor.getCursorScreenPosition().row + 1)
      AtomPHPCS.showErrorMessage(path, lineNo)

  updateStatus: (message) ->
    AtomPHPCS.statusBarTile.updateStatusBar(message)
