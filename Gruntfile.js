module.exports = function(grunt) {
  'use strict';

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
    watch: {
      js: {
        files: ['**/*.js', '!public/js/template.js'],
        tasks: ['jshint', 'jasmine']
      },
      jst: {
        files: ['public/js/template/**/*.jst'],
        tasks: ['jst', 'jasmine']
      },
      scss: {
        files: ['public/scss/**/*.scss'],
        tasks: ['compass', 'concat:css']
      }
    },

    jshint: {
      all: ['Gruntfile.js', 'public/js/**/*.js', 'spec/js/**/*.js', '!public/js/ext/**/*.js', '!public/js/template.js'],
      options: {
        globals: {
          jQuery: true,
          console: true,
          module: true
        },
        jshintrc: true,
        force: true
      }
    },

    jasmine: {
      all: {
        src: ['public/js/src/main.js'],
        options: {
          display: 'short',
          vendor: [
            'public/js/ext/sinonjs/sinon.js'
          ],
          keepRunner: true,
          specs: ['spec/js/**/*.js'],
          junit: {
            path: 'tmp/junit_output'
          },
          template: require('grunt-template-jasmine-requirejs'),
          templateOptions: {
            requireConfigFile: 'public/js/require-config.js'
          },
          outfile: 'public/_SpecRunner.html'
        }
      }
    },

    jst: {
      all: {
        files: { 'public/js/template.js': ['public/js/template/**/*.jst'] },
        options: {
          amd: true,
          processName: function(path) {
            return path.replace(/^public\/js\/template\//, '').replace(/\.jst$/, '');
          }
        }
      }
    },

    compass: {
      all: {
        options: {
          sassDir: 'public/scss',
          cssDir: 'public/css'
        }
      }
    },

    concat: {
      css: {
        src: ['public/css/screen.css', 'public/css/**/*.css', '!public/css/all.css'],
        dest: 'public/css/all.css'
      }
    }
  });

  grunt.loadNpmTasks('grunt-contrib-watch');
  grunt.loadNpmTasks('grunt-contrib-jshint');
  grunt.loadNpmTasks('grunt-contrib-jasmine');
  grunt.loadNpmTasks('grunt-contrib-jst');
  grunt.loadNpmTasks('grunt-contrib-compass');
  grunt.loadNpmTasks('grunt-contrib-concat');
};
