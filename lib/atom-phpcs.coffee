AtomPHPCSView = require './atom-phpcs-view'

module.exports =
  class AtomPHPCS
      config:
        standard:
            type: 'string'
            default: 'PEAR'
        path:
            type: 'string'
            default: 'phpcs'

      codesniff: ->
        editor = atom.workspace.getActiveTextEditor();
        if typeof editor == 'object'
            path = editor.getPath();
            if typeof path != 'undefined'
                if path.match('\.php$|\.inc$') isnt false
                  new AtomPHPCSView(editor)

      activate: ->
        @codesniff()

      sniffFile: (filepath, callback) ->
        command    = atom.config.get('atom-phpcs.path');
        standard   = atom.config.get('atom-phpcs.standard');
        directory  = filepath.replace(/\\/g, '/').replace(/\/[^\/]*$/, '')
        output     = []
        errorLines = []

        args = ["-n", "--report=csv", "--standard="+standard, filepath]

        options = {cwd: directory}

        stdout = (cs_output) ->
           output += cs_output.replace('\r', '').split('\n')

        stderr = (cs_error) ->
           errorLines += cs_error.replace('\r', '').split('\n')

        exit = (code) =>
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
              @cserrors[@filepath] = clean
              callback.call()

        new BufferedProcess({command, args, options, stdout, stderr, exit})
