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
require 'yaml'

class CloudsController < Sinatra::Base
  TEMPLATE_PATH = File.expand_path('../../config/templates.yml', File.dirname(__FILE__))

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
    begin
      json Cloud.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      status 404
      { error: "Cloud record(id = #{params[:id]}) not found" }.to_json
    end
  end

  post '/' do
    cloud = Cloud.new cloud_permit_params
    templates = YAML.load_file(TEMPLATE_PATH).symbolize_keys
    cloud.template = templates[cloud.type].to_json
    params[:targets].each do |target_params|
      cloud.targets.build target_permit_params(target_params)
    end
    unless cloud.save
      status 400
      return json cloud.errors
    end

    status 201
    json cloud
  end

  put '/:id' do
    begin
      cloud = Cloud.find(params[:id])
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end

    unless cloud.update_attributes cloud_permit_params
      status 400
      return json cloud.errors
    end

    status 200
    json cloud
  end

  delete '/:id' do
    begin
      cloud = Cloud.find(params[:id])
      cloud.destroy
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end

    status 204
  end

  def cloud_permit_params
    ActionController::Parameters.new(params).permit(:name, :type, :entry_point, :key, :secret, :tenant_id, :tenant_name)
  end

  def target_permit_params(target_params)
    ActionController::Parameters.new(target_params).permit(:operating_system_id, :source_image, :ssh_username)
  end
end
