define(['src/models/user', 'lib/session'], function(User, Session) {

  var Helper =  {
    login: function() {
      var loginUser = new User();
      loginUser.set("access_token", "23b689b60cb629a38e6b3bc62be61a82");
      Session.setCurrentUser(loginUser);
    },

    logout: function() {
      $.removeCookie("currentUser");
      Session.setCurrentUser(null);
    },

    spyOnFetch: function(target, func) {
      spyOn(target, "fetch").and.callFake(function() {
        func.apply(this);

        this.trigger("sync", this);
        return new $.Deferred().resolve();
      });
    }
  };

  window.Helper = Helper;
  return Helper;
});
