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
  register ConfigLoader

  get '/' do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || settings.per_page).to_i
    clouds = Cloud.limit(per_page).offset((page - 1) * per_page)
    headers link_header('/', Cloud.count, page, per_page)
    status 200
    json clouds
  end

  get '/:id' do
    begin
      cloud = Cloud.find(params[:id])
      status 200
      json cloud
    rescue ActiveRecord::RecordNotFound
      status 404
    end
  end

  post '/' do
    cloud = Cloud.new cloud_permit_params
    cloud.base_images.build source_image: params[:base_image_id]
    unless cloud.save
      status 400
      return json message: cloud.errors
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
      return json message: cloud.errors
    end

    status 200
    json cloud
  end

  delete '/:id' do
    begin
      cloud = Cloud.find(params[:id])
      if cloud.destroy
        status 204
      else
        status 400
        json message: cloud.errors
      end
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end
  end

  def cloud_permit_params
    ActionController::Parameters.new(params).permit(:name, :type, :entry_point, :key, :secret, :tenant_name)
  end
end
