define(function() {
  'use strict';

  function Sample() {
  }

  Sample.prototype.hoge = function() {
    this.piyo();
    return 0;
  };

  Sample.prototype.piyo = function() {
    return 5;
  };

  Sample.prototype.fetch = function() {
    return 4;
  };

  return Sample;
});
