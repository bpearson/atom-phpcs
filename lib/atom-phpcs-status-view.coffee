{Disposable} = require 'atom'

class AtomPHPCSStatusView extends HTMLElement
    initialize: ->
        @classList.add('atom-phpcs-status', 'inline-block')
        @goToLineLink = document.createElement('a')
        @goToLineLink.classList.add('inline-block')
        @goToLineLink.href = '#'
        @appendChild(@goToLineLink)

        @activeItemSubscription = atom.workspace.onDidChangeActivePaneItem (activeItem) =>
            @subscribeToActiveTextEditor()

        @subscribeToConfig()
        @subscribeToActiveTextEditor()

        @handleClick()

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

    handleClick: ->
        clickHandler = => atom.commands.dispatch(atom.views.getView(@getActiveTextEditor()), 'go-to-line:toggle')
        @addEventListener('click', clickHandler)
        @clickSubscription = new Disposable => @removeEventListener('click', clickHandler)

    getActiveTextEditor: ->
        atom.workspace.getActiveTextEditor()

    updateStatusBar: (message) ->
        if message?
            @goToLineLink.textContent = message
            @classList.remove('hide')
        else
            @goToLineLink.textContent = ''
            @classList.add('hide')

module.exports = document.registerElement('atom-phpcs-status', prototype: AtomPHPCSStatusView.prototype, extends: 'div')
