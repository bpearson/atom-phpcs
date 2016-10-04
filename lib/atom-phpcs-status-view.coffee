{Disposable} = require 'atom'

class AtomPHPCSStatusView extends HTMLElement
  initialize: ->
    @tooltip = null
    @classList.add('atom-phpcs-status', 'inline-block')
    @statusMessage = document.createElement('span')
    @appendChild(@statusMessage)

    @activeItemSubscription = atom.workspace.onDidChangeActivePaneItem (activeItem) =>
      @subscribeToActiveTextEditor()

    @subscribeToConfig()
    @subscribeToActiveTextEditor()

  destroy: ->
    @activeItemSubscription.dispose()
    @cursorSubscription?.dispose()
    @configSubscription?.dispose()
    @clickSubscription.dispose()

  subscribeToActiveTextEditor: ->
    @cursorSubscription?.dispose()
    @cursorSubscription = @getActiveTextEditor()?.onDidChangeCursorPosition =>
      @updateStatusBar('')
    @updateStatusBar('')

  subscribeToConfig: ->
    @configSubscription?.dispose()
    @configSubscription = atom.config.observe 'status-bar.cursorPositionFormat', (value) =>
      @updateStatusBar('')

  getActiveTextEditor: ->
    atom.workspace.getActiveTextEditor()

  updateStatusBar: (message) ->
    if @tooltip?
      @tooltip.dispose()

    if message?
      @statusMessage.textContent = message
      @classList.remove('hide')
    else
      @statusMessage.textContent = ''
      @classList.add('hide')

    @tooltip = atom.tooltips.add(@statusMessage, {title: message})

module.exports = document.registerElement('atom-phpcs-status', prototype: AtomPHPCSStatusView.prototype, extends: 'div')
