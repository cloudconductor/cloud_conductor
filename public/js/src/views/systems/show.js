// Copyright 2014 TIS inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
define(['extended-view', 'jst', 'src/models/system'], function(ExtendedView, JST, System) {
  'use strict';

  return ExtendedView.extend({
    events: {
    },

    template: JST['systems/show'],

    initialize: function(options){
      ExtendedView.prototype.initialize.apply(this, arguments);

      _.bindAll(this);
      this.system = new System({id: options.id});

      this.wait(this.system.fetch());
    },

    onload: function() {
    },

    render: function() {
      this.$el.html(this.template(this.system.attributes));
    }
  });
});
