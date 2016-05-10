module.exports = (grunt) ->
  # load plugins
  grunt.loadNpmTasks('grunt-contrib-watch')
  grunt.loadNpmTasks('grunt-contrib-clean')
  #grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-browserify')
  grunt.loadNpmTasks('grunt-contrib-compress')
  grunt.loadNpmTasks('grunt-contrib-less')
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-coffeelint')
  grunt.loadNpmTasks('grunt-bump')

  grunt.initConfig {
    pkg: grunt.file.readJSON('package.json'),
    watch:
      options:
        livereload: true
      coffee:
        files: [
          'Gruntfile.coffee',
          'src/*.coffee',
          'src/plugins/*.coffee'
        ],
        tasks: [
          'browserify',
          #'uglify',
          'less:development'
        ],
      less:
        files: 'src/*.less',
        tasks: 'less:development'
    browserify:
      dist:
        files:
          'build/d3.timeslider.js': 'src/main.coffee'
        options:
          transform: [['coffeeify', {
            sourceMap: true
          }]]
    # coffee:
    #   compile:
    #     options:
    #       join: true,
    #       sourceMap: true
    #     files:
    #       'build/d3.timeslider.js': 'src/*.coffee'
    #       'build/d3.timeslider.plugins.js': 'src/plugins/*.coffee'
    coffeelint:
      options:
        indentation:
          value: 4
        max_line_length:
          value: 120
        no_backticks:
          level: "ignore"
      app: 'src/*.coffee'
    uglify:
      options:
        banner: '/* <%= pkg.name %> - version <%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %>\n * See <%= pkg.homepage %> for more information! */\n',
        mangle:
          except: ['d3', 'filter', 'map']
        report: 'gzip'
        preserveComment: false
      compile:
        files:
          'build/d3.timeslider.min.js': ['build/d3.timeslider.js']
          'build/d3.timeslider.plugins.min.js': ['build/d3.timeslider.plugins.js']
    less:
      development:
        files:
          'build/d3.timeslider.css': 'src/*.less'
      production:
        options:
          yuicompress: true
        files:
            'build/d3.timeslider.min.css': 'src/*.less'
    bump:
      options:
        files: ['package.json'],
        updateConfigs: ['pkg'],
        push: false,
    clean:
      build: [ 'build/*' ]
      release: [ 'release/*' ]
    compress:
      release:
        options:
          archive: 'release/d3.TimeSlider.zip'
        files: [
          { expand: true, cwd: 'build', src: ['*.min.js', '*.min.css'], dest: 'd3.timeslider' },
          { expand: true, src: ['License', 'Readme.md', 'Changelog'], dest: 'd3.timeslider' }
        ]
  }

  grunt.registerTask('lint', ['coffeelint'])
  grunt.registerTask('default', ['clean:build', 'browserify', #'uglify',
    'less:development'])
  grunt.registerTask('release', ['clean:release', 'bump', 'coffee', 'uglify', 'less:production', 'compress:release'])
