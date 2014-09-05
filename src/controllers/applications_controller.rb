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
module ApplicationsController
  # rubocop:disable MethodLength, CyclomaticComplexity
  def self.registered(base)
    base.get do
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || 5).to_i

      state = {}
      state[:total_pages] = (Application.count / per_page.to_f).ceil

      json [state, Application.limit(per_page).offset((page - 1) * per_page)]
    end

    base.get '/:id' do
      json Application.find(params[:id])
    end

    base.get '/:id/:version' do
      json ApplicationHistory.where(application_id: params[:id], version: params[:version])
    end

    base.post do
      application = Application.new application_permit_params
      application.histories.build history_permit_params
      unless application.save
        status 400
        return json application.errors
      end

      status 201
      json application
    end

    base.put '/:id' do
      begin
        application = Application.find(params[:id])
      rescue => e
        Log.error e
        status 400
        return json message: e.message
      end

      begin
        application.transaction do
          application.update_attributes! application_permit_params
          application.histories.build history_permit_params
          application.save!
        end
      rescue => e
        status 400
        return json message: e.message
      end

      status 200
      json application
    end

    base.delete '/:id' do
      begin
        Application.find(params[:id]).destroy
      rescue => e
        Log.error e
        status 400
        return json message: e.message
      end

      status 204
    end
  end

  def application_permit_params
    ActionController::Parameters.new(params).permit(:system_id, :name)
  end

  def history_permit_params
    ActionController::Parameters.new(params).permit(:url, :parameters)
  end
end
