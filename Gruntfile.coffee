fs = require "fs"
path = require "path"
hljs = require "highlight.js"
jade = require './node_modules/grunt-contrib-jade/node_modules/jade'

marked = require "marked"
marked.setOptions gfm:true

module.exports = (grunt) ->

  #load external tasks and change working directory
  grunt.source.loadAllTasks()

  #output files
  output = grunt.source.output or {}
  grunt.util._.defaults output,
    js: "js/app.js"
    css: "css/app.css"
    html: "../index.html"

  #check options
  env = grunt.option "env"
  env = "dev" unless env in ["dev","prod"]
  dev = env is "dev"

  #jade data
  jadeData =
    JSON: JSON
    showCodeFile: (file) ->
      lang = switch path.extname(file)
        when ".js"
          "javascript"
        when ".coffee"
          "coffeescript"
        else
          "bash"

      code = jadeData.showFile file
      

      code = code.replace(/(require\(['"])([\.\/]+)(['"]\))/, "$1#{grunt.source.name}$3")

      html = jadeData.showCode lang, code
      html

    showCode: (lang, str) ->
      html = hljs.highlight(lang, str).value
      "<pre><code>#{html}</code></pre>"

    showFile: (file) ->
      grunt.file.read path.join "..", file
    source: grunt.source
    env: env
    min: if env is 'prod' then '.min' else ''
    dev: dev
    date: new Date()
    manifest: "<%= manifest.generate.dest %>"
    css: "<style>#{grunt.file.read(output.css)}</style>"
    js: "<script>#{grunt.file.read(output.js)}</script>"

  #include directory helper
  includeDir = (dir) ->
    unless grunt.file.isDir dir
      grunt.log.writeln "Not a directory: #{dir}"
      return ""
    results = ""
    fs.readdirSync(dir).forEach (file) ->
      full = path.join dir, file
      return if grunt.file.isDir full
      input = grunt.file.read full
      data = Object.create jadeData
      data.includeDir = (subdir) ->
        includeDir path.join dir, subdir
      output = jade.compile(input,{pretty:dev,doctype:"5"})(data)
      results += output + "\n"
    return results

  #root include dir
  jadeData.includeDir = (dir) ->
    includeDir path.join "src", "views", dir

  #initialise config
  grunt.initConfig
    #watcher
    watch:
      scripts:
        files: 'src/scripts/**/*.coffee'
        tasks: 'scripts'
      vendor:
        files: 'src/scripts/vendor/**/*.js'
        tasks: 'scripts-pack'
      views:
        files: 'src/views/**/*.jade'
        tasks: 'views'
      styles:
        files: 'src/styles/**/*.{css,styl}'
        tasks: 'styles'
      config:
        files: ['Gruntsource.json']
        tasks: 'default'

    #tasks
    coffee:
      compile:
        src: [
          "src/scripts/init.coffee",
          "src/scripts/**/*.coffee",
          #remove and re-add to insert at bottom
          "!src/scripts/run.coffee",
          "src/scripts/run.coffee"
        ]
        dest: output.js
        options:
          bare: false
          join: true
    concat:
      scripts:
        src: ["src/scripts/vendor/*.js", output.js]
        dest: output.js
    ngmin:
      app:
        src: output.js
        dest: output.js
    uglify:
      compress:
        src: output.js
        dest: output.js
    jade:
      compile:
        src: "src/views/index.jade"
        dest: output.html
        options:
          pretty: dev
          doctype: "5"
          data: jadeData
    stylus:
      compile:
        src: "src/styles/app.styl"
        dest: output.css
        options:
          urlfunc: 'embedurl'
          define:
            source: grunt.source
          compress: not dev
          linenos: dev
          'include css': true
          paths: ["src/styles/embed/","../"]
    cssmin:
      compress:
        src: output.css
        dest: output.css

    #appcache
    manifest:
      generate:
        options:
          # basePath: '../',
          network: ['*']
          # fallback: ['/ /offline.html'],
          preferOnline: true
          verbose: false
          timestamp: true
        src: [
          'css/img/**/*.*'
          output.css
          output.js
        ]
        dest: 'appcache'

  #task groups
  grunt.registerTask "scripts-compile",      ["coffee"]
  grunt.registerTask "scripts-pack", ["concat:scripts"].
                                  concat(if not dev and grunt.source.angular then ["ngmin"] else []).
                                  concat(if dev then [] else ["uglify"])
  grunt.registerTask "scripts", ["scripts-compile","scripts-pack"]
  grunt.registerTask "styles",  ["stylus"].concat(if dev then [] else ["cssmin"])
  grunt.registerTask "views",   ["jade"]
  grunt.registerTask "build",   ["scripts","styles","views"]
  grunt.registerTask "default", ["build","watch"]
