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
(function(){
  "use strict";
  //  Dialog再表示に位置がずれる原因はjquery-uiの後方互換機能だったため
  //  後方互換機能をoffにする必要がある
  //  offにするタイミングはjquery.js読み込み後、jquery.ui(.dialog).js読み込み前のみ可能なので
  //  新規ファイルを作成し、上記二つの間に読み込ませる事で対応した。
  $.uiBackCompat = false;
})();
