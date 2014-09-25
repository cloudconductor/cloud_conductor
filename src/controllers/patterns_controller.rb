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
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 5).to_i

    state = {}
    state[:total_pages] = (Pattern.count / per_page.to_f).ceil

    json [state, Pattern.limit(per_page).offset((page - 1) * per_page)]
  end

  get '/:id' do
    json Pattern.find(params[:id])
  end

  post '/' do
    pattern = Pattern.new permit_params
    (params[:clouds] || Cloud.all.map(&:id)).each do |cloud|
      pattern.clouds << Cloud.find(cloud)
    end

    unless pattern.save
      status 400
      return json pattern.errors
    end

    status 201
    json pattern
  end

  delete '/:id' do
    begin
      pattern = Pattern.find(params[:id])
      pattern.destroy
    rescue => e
      Log.error e
      status 400
      return json message: e.message
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
