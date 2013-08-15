module.exports = (grunt) ->
  # load plugins
  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-coffeelint');
  grunt.loadNpmTasks('grunt-bump');

  grunt.initConfig {
    pkg: grunt.file.readJSON('package.json'),
    watch:
      options:
        livereload: true
      coffee:
        files: 'src/*.coffee',
        tasks: 'coffee'
      less:
        files: 'src/*.less',
        tasks: 'less:development'
    coffee:
      compile:
        options:
          join: true,
          sourceMap: true
        files:
          'build/d3.timeslider.js': 'src/*.coffee'
    coffeelint:
      options:
        indentation:
          value: 4
        max_line_length:
          value: 120
      app: 'src/*.coffee'
    uglify:
      options:
        banner: '/* <%= pkg.name %> - version <%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %>\n * See <%= pkg.homepage %> for more information! */\n',
        mangle:
          except: 'd3'
        report: 'gzip'
        preserveComment: false
        sourceMap: 'build/d3.timeslider.min.js.map',
        sourceMapRoot: 'src/',
        sourceMapIn: 'build/d3.timeslider.js.map'
      compile:
        files:
          'build/d3.timeslider.min.js': ['build/d3.timeslider.js']
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
        commit: false,
        createTag: false,
        push: false,
        pushTo: 'origin',
  }

  grunt.registerTask('default', ['lint', 'coffee', 'uglify', 'less:production'])
  grunt.registerTask('lint', ['coffeelint'])
  grunt.registerTask('release', ['bump', 'coffee', 'uglify', 'less:production',])
