define(['src/models/system', 'src/collections/systems', 'src/views/systems/index', 'extended-view'], function(System, Systems, SystemsIndex, ExtendedView) {
  'use strict';

  describe("SystemsIndex", function() {
    beforeEach(function() {
      Helper.spyOnFetch(Systems.prototype, function() {
        this.state.firstPage = 1;
        this.state.currentPage = 1;
        this.state.totalPages = 1;

        for(var i=0; i<3; i++) {
          var system = new System();
          system.set("id", i);
          system.set("name", "name");
          system.set("cloud_name", "dummy_cloud_name");
          this.push(system);
        }
      });

      this.page = new SystemsIndex();
    });

    describe("#render", function() {
      it("は与えられたコレクションの件数分DOMにtrタグを追加する", function() {
        expect(this.page.$("tbody > tr").length).toEqual(3);
      });

      it("は与えられたコレクションの内容を正しくテーブルに表示する", function() {
        expect(this.page.$("table tbody tr:first-child td").eq(0).text()).toEqual("0");
        expect(this.page.$("table tbody tr:first-child td").eq(1).text()).toEqual("name");
        expect(this.page.$("table tbody tr:first-child td").eq(2).text()).toEqual("dummy_cloud_name");
      });

      it("は最初のページの場合、前ページへのリンクを無効化する", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 1;
        systems.state.totalPages = 1;
        systems.trigger("sync", systems);

        expect(this.page.$(".pagination > li:first").hasClass("disabled")).toBeTruthy();
      });

      it("は前ページが存在する場合、前ページへのリンクを有効化する", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 2;
        systems.state.totalPages = 2;
        systems.trigger("sync", systems);

        expect(this.page.$(".pagination > li:first").hasClass("disabled")).toBeFalsy();
      });

      it("は最後のページの場合、次ページへのリンクを無効化する", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 5;
        systems.state.totalPages = 5;
        systems.trigger("sync", systems);

        expect(this.page.$(".pagination > li:last").hasClass("disabled")).toBeTruthy();
      });

      it("は次ページが存在する場合、次ページへのリンクを有効化する", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 4;
        systems.state.totalPages = 5;
        systems.trigger("sync", systems);

        expect(this.page.$(".pagination > li:last").hasClass("disabled")).toBeFalsy();
      });
    });

    describe("click .prevPage", function() {
      it("はCollection#getPreviousPageを呼ぶ", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 4;
        systems.state.totalPages = 5;
        spyOn(systems, 'getPreviousPage').and.callFake(function() {});

        systems.trigger("sync", systems);

        this.page.$(".prevPage").click();
        expect(systems.getPreviousPage).toHaveBeenCalled();
      });
    });

    describe("click .nextPage", function() {
      it("はCollection#getNextPageを呼ぶ", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 4;
        systems.state.totalPages = 5;
        spyOn(systems, 'getNextPage').and.callFake(function() {});

        systems.trigger("sync", systems);

        this.page.$(".nextPage").click();
        expect(systems.getNextPage).toHaveBeenCalled();
      });
    });

    describe("click .goTo", function() {
      it("は押されたページを引数としてCollection#getPageを呼ぶ", function() {
        var systems = this.page.collection;
        systems.state.firstPage = 1;
        systems.state.currentPage = 1;
        systems.state.totalPages = 5;
        spyOn(systems, 'getPage').and.callFake(function() {});

        systems.trigger("sync", systems);

        this.page.$(".goTo").eq(2).click();
        expect(systems.getPage).toHaveBeenCalledWith(3);
      });
    });

    describe("#wait", function() {
      beforeEach(function() {
        this.server = sinon.fakeServer.create();

        spyOn(this.page, "render").and.callThrough();

        //  別画面へ遷移する途中でエラーが発生
        var system = new System({id: 1});
        var page = new ExtendedView({tagName: "table", className: "sample"});
        page.wait(system.fetch());

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
});
