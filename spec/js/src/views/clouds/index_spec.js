define(['src/models/cloud', 'src/collections/clouds', 'src/views/clouds/index', 'extended-view'], function(Cloud, Clouds, CloudsIndex, ExtendedView) {
  'use strict';

  beforeEach(function() {
    Helper.spyOnFetch(Clouds.prototype, function() {
      this.state.firstPage = 1;
      this.state.currentPage = 1;
      this.state.totalPages = 1;

      for(var i=0; i<3; i++) {
        var cloud = new Cloud();
        cloud.set("id", i);
        cloud.set("name", "name");
        cloud.set("cloud_type", "dummy_cloud_type");
        this.push(cloud);
      }
    });

    this.page = new CloudsIndex();
  });

  describe("#render", function() {
    it("は与えられたコレクションの件数分DOMにtrタグを追加する", function() {
      expect(this.page.$("tbody > tr").length).toEqual(3);
    });

    it("は与えられたコレクションの内容を正しくテーブルに表示する", function() {
      expect(this.page.$("table tbody tr:first-child td").eq(0).text()).toEqual("0");
      expect(this.page.$("table tbody tr:first-child td").eq(1).text()).toEqual("name");
      expect(this.page.$("table tbody tr:first-child td").eq(2).text()).toEqual("dummy_cloud_type");
    });

    it("は最初のページの場合、前ページへのリンクを無効化する", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 1;
      clouds.state.totalPages = 1;
      clouds.trigger("sync", clouds);

      expect(this.page.$(".pagination > li:first").hasClass("disabled")).toBeTruthy();
    });

    it("は前ページが存在する場合、前ページへのリンクを有効化する", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 2;
      clouds.state.totalPages = 2;
      clouds.trigger("sync", clouds);

      expect(this.page.$(".pagination > li:first").hasClass("disabled")).toBeFalsy();
    });

    it("は最後のページの場合、次ページへのリンクを無効化する", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 5;
      clouds.state.totalPages = 5;
      clouds.trigger("sync", clouds);

      expect(this.page.$(".pagination > li:last").hasClass("disabled")).toBeTruthy();
    });

    it("は次ページが存在する場合、次ページへのリンクを有効化する", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 4;
      clouds.state.totalPages = 5;
      clouds.trigger("sync", clouds);

      expect(this.page.$(".pagination > li:last").hasClass("disabled")).toBeFalsy();
    });
  });

  describe("click .prevPage", function() {
    it("はCollection#getPreviousPageを呼ぶ", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 4;
      clouds.state.totalPages = 5;
      spyOn(clouds, 'getPreviousPage').and.callFake(function() {});

      clouds.trigger("sync", clouds);

      this.page.$(".prevPage").click();
      expect(clouds.getPreviousPage).toHaveBeenCalled();
    });
  });

  describe("click .nextPage", function() {
    it("はCollection#getNextPageを呼ぶ", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 4;
      clouds.state.totalPages = 5;
      spyOn(clouds, 'getNextPage').and.callFake(function() {});

      clouds.trigger("sync", clouds);

      this.page.$(".nextPage").click();
      expect(clouds.getNextPage).toHaveBeenCalled();
    });
  });

  describe("click .goTo", function() {
    it("は押されたページを引数としてCollection#getPageを呼ぶ", function() {
      var clouds = this.page.collection;
      clouds.state.firstPage = 1;
      clouds.state.currentPage = 1;
      clouds.state.totalPages = 5;
      spyOn(clouds, 'getPage').and.callFake(function() {});

      clouds.trigger("sync", clouds);

      this.page.$(".goTo").eq(2).click();
      expect(clouds.getPage).toHaveBeenCalledWith(3);
    });
  });

  describe("#wait", function() {
    beforeEach(function() {
      this.server = sinon.fakeServer.create();

      spyOn(this.page, "render").and.callThrough();

      //  別画面へ遷移する途中でエラーが発生
      var cloud = new Cloud({id: 1});
      var page = new ExtendedView({tagName: "table", className: "sample"});
      page.wait(cloud.fetch());

      var headers = { "Content-Type": "application/json" };
      var body = JSON.stringify({ result: "error", message: "予期せぬエラーが発生しました。" });
      _.last(this.server.requests).respond(500, headers, body);
    });

    afterEach(function() {
      this.server.restore();
    });

    it("はfailした場合、遷移前画面にエラー表示を行う", function() {
      expect(this.page.errors.length).toEqual(1);
      expect(this.page.render).toHaveBeenCalled();

      expect(this.page.$(".alert-danger").length).toEqual(1);
    });
  });
});
