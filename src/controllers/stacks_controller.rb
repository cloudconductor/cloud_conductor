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
class StacksController < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get '/' do
    page = (params[:page] || 1).to_i
    per_page = (params[:per_page] || 5).to_i

    state = {}
    state[:total_pages] = (Stack.count / per_page.to_f).ceil

    json [state, Stack.limit(per_page).offset((page - 1) * per_page)]
  end

  get '/:id' do
    json Stack.find(params[:id])
  end

  post '/' do
    stack = Stack.new permit_params

    unless stack.save
      status 400
      return json stack.errors
    end

    status 201
    json stack
  end

  put '/:id' do
    begin
      stack = Stack.find(params[:id])
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end

    unless stack.update_attributes permit_params
      status 400
      return json stack.errors
    end

    status 200
  end

  delete '/:id' do
    begin
      stack = Stack.find(params[:id])
      stack.destroy
    rescue => e
      Log.error e
      status 400
      return json message: e.message
    end
  end

  def permit_params
    ActionController::Parameters.new(params)
      .permit(:system_id, :pattern_id, :cloud_id, :name, :template_parameters, :parameters)
  end
end
