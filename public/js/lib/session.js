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
define(['jquery-cookie', 'src/models/user'], function(User) {
  'use strict';

  return {
    isLogin: function() {
      return !!$.cookie('access_token');
    },

    setAccessToken: function(token) {
      $.cookie('access_token', token);
    },

    getAccessToken: function() {
      return $.cookie('access_token');
    },

    //  ログイン
    login: function() {
      var hash = location.hash;
      if(hash === '#login' || hash === '#logout') {
        hash = '#main';
      }
      $.cookie('back_hash', hash.replace(/^#/, ''));
      location.assign("oauth/authorize");
    },

    //  ログアウト
    logout: function() {
      this.currentUser = undefined;
      $.removeCookie('access_token');
    },

    getCurrentUser: function() {
      if(!this.isLogin()) {
        this.login();
        return new $.Deferred().reject();
      }

      if(this.currentUser) {
        return new $.Deferred().resolve(this.currentUser);
      }

      var deferred = new $.Deferred();
      new User().fetch({
        success: function(user) {
          this.currentUser = user;
          deferred.resolve(user);
        },
        error: function() {
          this.logout();
          deferred.reject();
        }
      });

      return deferred;
    }
  };
});
