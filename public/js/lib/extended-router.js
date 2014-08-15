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
(function() {
  'use strict';

  Backbone.Router = Backbone.Router.extend({
    beforeRoute: function(route) { return true; },
    route: function(route, name, callback) {
      if (!_.isRegExp(route)) { route = this._routeToRegExp(route); }
      if (_.isFunction(name)) {
        callback = name;
        name = '';
      }
      if (!callback) { callback = this[name]; }
      var router = this;
      Backbone.history.route(route, function(fragment) {
        var args = router._extractParameters(route, fragment);

        if(router.beforeRoute.apply(router, arguments)) {
          callback && callback.apply(router, args);
          router.trigger.apply(router, ['route:' + name].concat(args));
          router.trigger('route', name, args);
          Backbone.history.trigger('route', router, name, args);
        }
      });
      return this;
    }
  });
})();
