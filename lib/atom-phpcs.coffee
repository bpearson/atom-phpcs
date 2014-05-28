AtomPHPCSView = require './atom-phpcs-view'

module.exports =
  activate: ->
    atom.workspaceView.eachEditorView (editorView) ->
      if editorView.editor.getPath().match('\.php$|\.inc$') isnt false
        new AtomPHPCSView(editorView)
