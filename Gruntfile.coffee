module.exports = (grunt) ->
  # TODO
  #  * Take a look at https://github.com/gruntjs/grunt-contrib-compress

  # load plugins
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-contrib-less');
  grunt.loadNpmTasks('grunt-contrib-uglify');
  grunt.loadNpmTasks('grunt-coffeelint');

  grunt.initConfig {
    pkg: grunt.file.readJSON('package.json'),
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
      app: 'src/*.coffee'
    uglify:
      options:
        banner: '/* <%= pkg.name %> - v<%= pkg.version %> - <%= grunt.template.today("yyyy-mm-dd") %>\n * See <%= pkg.homepage %> for more information! */\n',
        mangle:
          except: 'd3'
        report: 'gzip'
        preserveComment: false
        sourceMap: 'build/d3.timeslider.min.js.map',
        sourceMapRoot: 'src/',
        sourceMapIn: 'build/d3.timeslider.js.map'
      compile:
        files:
          'build/d3.timeslider.min.js': ['build/*.js']
    less:
      development:
        files:
          'build/d3.timeslider.css': 'src/*.less'
      production:
        options:
          yuicompress: true
        files:
            'build/d3.timeslider.min.css': 'src/*.less'
    }

  grunt.registerTask('default', ['coffee', 'uglify', 'less']);
