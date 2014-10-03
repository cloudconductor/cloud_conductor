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
class PatternsController < Sinatra::Base
  register ConfigLoader

  get '/' do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || settings.per_page).to_i
    patterns = Pattern.limit(per_page).offset((page - 1) * per_page)
    headers link_header('/', Pattern.count, page, per_page)
    status 200
    json patterns
  end

  get '/:id' do
    begin
      pattern = Pattern.find(params[:id])
      status 200
      json pattern
    rescue ActiveRecord::RecordNotFound
      status 404
    end
  end

  post '/' do
    pattern = Pattern.new permit_params
    clouds = params[:clouds] || Cloud.all.map(&:id)
    clouds.each do |cloud_id|
      begin
        cloud = Cloud.find(cloud_id)
        pattern.clouds << cloud
      rescue ActiveRecord::RecordNotFound
        status 400
        json message: 'Specified cloud does not exist'
        return
      end
    end
    if pattern.save
      status 201
      json pattern
    else
      status 400
      json message: pattern.errors
    end
  end

  delete '/:id' do
    begin
      pattern = Pattern.find(params[:id])
      if pattern.destroy
        status 204
      else
        status 400
      end
    rescue ActiveRecord::RecordNotFound
      status 404
    end
  end

  get '/:id/parameters' do
    begin
      pattern = Pattern.find(params[:id])
      status 200
      pattern.parameters
    rescue ActiveRecord::RecordNotFound
      status 404
    end
  end

  def permit_params
    ActionController::Parameters.new(params)
      .permit(:url, :revision, :parameters)
  end
end
