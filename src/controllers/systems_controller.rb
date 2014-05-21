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
  configure :development do
    register Sinatra::Reloader
  end

  set(:clone) do |is_clone|
    condition do
      is_clone ? params[:system_id] : params[:system_id].nil?
    end
  end

  get '/' do
    json System.all
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
    rescue
      status 400
      return '{ "message": "Template system does not exist" }'
    end

    system = previous_system.dup
    unless system.save
      status 400
      return json system.errors
    end

    status 201
    json system
  end

  def permit_params
    ActionController::Parameters.new(params)
      .permit(:name, :template_body, :template_url, :parameters)
  end
end
