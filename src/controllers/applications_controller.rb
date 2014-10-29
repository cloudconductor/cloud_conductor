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
  def self.registered(base) # rubocop:disable MethodLength, CyclomaticComplexity, PerceivedComplexity
    base.get do
      page = (params[:page] || 1).to_i
      per_page = (params[:per_page] || settings.per_page).to_i
      applications = Application.where(system_id: params[:system_id]).limit(per_page).offset((page - 1) * per_page)
      count = Application.where(system_id: params[:system_id]).count
      headers link_header("/#{params[:system_id]}/applications", count, page, per_page)
      status 200
      json applications
    end

    base.get '/:id' do
      application = Application.where(id: params[:id], system_id: params[:system_id]).first
      if application.nil?
        status 404
      else
        status 200
        json application
      end
    end

    base.get '/:id/:version' do
      application = Application.where(id: params[:id], system_id: params[:system_id]).first
      if application.nil?
        status 404
        return
      end

      application_history = application.histories.where(version: params[:version]).first
      if application_history.nil?
        status 404
      else
        status 200
        json application_history
      end
    end

    base.post do
      application = Application.new application_permit_params
      application.histories.build history_permit_params
      if application.save
        status 201
        json application
      else
        status 400
        json message: application.errors
      end
    end

    base.put '/:id' do
      application = Application.where(id: params[:id], system_id: params[:system_id]).first
      if application.nil?
        status 404
        return
      end
      begin
        application.transaction do
          application.update_attributes! application_permit_params
          application.histories.build history_permit_params
          application.save!
        end
        status 200
        json application
      rescue ActiveRecord::RecordInvalid
        status 400
        json message: application.errors
      end
    end

    base.delete '/:id' do
      application = Application.where(id: params[:id], system_id: params[:system_id]).first
      if application.nil?
        status 404
      else
        if application.destroy
          status 204
        else
          status 400
          json message: application.errors
        end
      end
    end
  end

  def application_permit_params
    ActionController::Parameters.new(params).permit(:system_id, :name)
  end

  # rubocop:disable LineLength
  def history_permit_params
    ActionController::Parameters.new(params).permit(:domain, :type, :protocol, :url, :revision, :pre_deploy, :post_deploy, :parameters)
  end
end
