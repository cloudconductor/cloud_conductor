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
var deps = [];
deps.push('backbone');
deps.push('i18n');
deps.push('src/routers/system_router');
deps.push('src/routers/cloud_router');

define(deps, function(Backbone, i18n, SystemRouter, CloudRouter) {
  'use strict';

  $(function() {
    i18n.init({ debug: true, useCookie: false, fallbackLng: 'en' }, function() {
//      for(var key in App.Routers) {
//        if(App.Routers.hasOwnProperty(key)) {
//          new App.Routers[key]();
//        }
//      }
      new SystemRouter();
      new CloudRouter();

      Backbone.history.start();

      if(location.href.match(/\/$/) && location.hash === "") {
        Backbone.history.navigate("main", { trigger: true, replace: true });
      }

      // ActivityIndicatorを動的生成
      $("body").append($("<div>").addClass("activity-indicator"));
      //$("div.activity-indicator").activity();
    });
  });
});
