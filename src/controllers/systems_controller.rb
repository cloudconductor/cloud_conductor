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
class SystemsController < Sinatra::Base
  register Sinatra::Namespace, ConfigLoader

  namespace '/:system_id/applications' do
    register ApplicationsController
    include ApplicationsController
  end

  namespace '/:system_id/stacks' do
    register StacksController
    include StacksController
  end

  set(:clone) do |is_clone|
    condition do
      is_clone ? params[:system_id] : params[:system_id].nil?
    end
  end

  get '/' do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || settings.per_page).to_i
    systems = System.limit(per_page).offset((page - 1) * per_page)
    headers link_header('/', System.count, page, per_page)
    status 200
    json systems
  end

  get '/:id' do
    json System.find(params[:id])
  end

  post '/', clone: false do
    system = System.new permit_params
    (params[:clouds] || []).each do |cloud|
      system.add_cloud Cloud.find(cloud[:id]), cloud[:priority]
    end

    unless system.save
      status 400
      return json system.errors
    end

    status 201
    json system
  end

  post '/', clone: true do
    begin
      previous_system = System.find(params[:system_id])
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end

    system = previous_system.dup
    unless system.save
      status 400
      return json system.errors
    end

    status 201
    json system
  end

  put '/:id' do
    begin
      system = System.find(params[:id])
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end

    unless system.update_attributes permit_params
      status 400
      return json system.errors
    end

    status 200
  end

  delete '/:id' do
    begin
      system = System.find(params[:id])
      system.destroy
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end
  end

  def permit_params
    ActionController::Parameters.new(params)
      .permit(:name, :monitoring_host, :domain)
  end
end
