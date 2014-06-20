module.exports = function(grunt) {
  'use strict';

  grunt.initConfig({
    pkg: grunt.file.readJSON('package.json'),
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
    }
  });

  grunt.loadNpmTasks('grunt-contrib-jshint');
};
