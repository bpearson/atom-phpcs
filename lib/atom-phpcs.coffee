AtomPHPCSView = require './atom-phpcs-view'

module.exports =
  configDefaults:
    standard: 'PEAR'
    path: 'phpcs'

  codesniff: ->
    atom.config.setDefaults('atom-phpcs', this.configDefaults);
    atom.workspaceView.eachEditorView (editorView) ->
      path = editorView.editor.getPath()
      if typeof path != 'undefined'
        if path.match('\.php$|\.inc$') isnt false
          new AtomPHPCSView(editorView)

  activate: ->
    @codesniff()
