# Copyright 2014 TIS inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
class CloudsController < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 5).to_i

    state = {}
    state[:total_pages] = (Cloud.count / per_page.to_f).ceil

    json [state, Cloud.limit(per_page).offset((page - 1) * per_page)]
  end

  get '/:id' do
    json Cloud.find(params[:id])
  end

  post '/' do
    cloud = Cloud.new permit_params
    puts cloud.save
    status 201
    json cloud
  end

  delete '/:id' do
    Cloud.find(params[:id]).destroy
    status 204
  end

  def permit_params
    ActionController::Parameters.new(params).permit(:name, :type, :key, :secret, :tenant_id)
  end
end
