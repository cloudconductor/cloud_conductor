module API
  module V1
    class CloudAPI < API::V1::Base
      resource :clouds do
        before do
          @project_id = nil
          if params.key?(:project_id)
            @project_id = params[:project_id]
          end

          if @project_id == nil && params.key?(:id)
            cloud = Cloud.find_by_id(params[:id])
            @project_id = cloud.project_id if cloud
          end
        end

        after do
          track_api(@project_id)
        end

        desc 'List clouds'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          ::Cloud.where(params.slice(:project_id).to_hash).select do |cloud|
            can?(:read, cloud)
          end
        end

        desc 'Show cloud'
        params do
          requires :id, type: Integer, desc: 'Cloud id'
        end
        get '/:id' do
          cloud = ::Cloud.find(params[:id])
          authorize!(:read, cloud)
          cloud
        end

        desc 'Create cloud'
        params do
          requires :project_id, type: Integer, exists_id: :project, desc: 'Project id'
          requires :name, type: String, desc: 'Cloud name'
          requires :type, type: String, desc: 'Cloud type (aws or openstack)'
          requires :key, type: String, desc: 'AccessKey or username to authenticate cloud'
          requires :secret, type: String, desc: 'SecretKey or password to authenticate cloud'
          requires :entry_point, type: String, desc: 'Entry point (e.g. ap-northeast-1 or http://<your-openstack>:5000/)'
          optional :description, type: String, desc: 'Cloud description'
          optional :tenant_name, type: String, desc: 'Tenant name (OpenStack only)'
        end
        post '/' do
          project = ::Project.find_by(id: params[:project_id])
          authorize!(:read, project)
          authorize!(:create, ::Cloud, project: project)
          ::Cloud.create!(declared_params)
        end

        desc 'Update cloud'
        params do
          requires :id, type: Integer, desc: 'Cloud id'
          optional :name, type: String, desc: 'Cloud name'
          optional :type, type: String, desc: 'Cloud type (aws or openstack)'
          optional :key, type: String, desc: 'AccessKey or username to authenticate cloud'
          optional :secret, type: String, desc: 'SecretKey or password to authenticate cloud'
          optional :entry_point, type: String, desc: 'Entry point (e.g. ap-northeast-1 or http://<your-openstack>:5000/)'
          optional :description, type: String, desc: 'Cloud description'
          optional :tenant_name, type: String, desc: 'Tenant name (OpenStack only)'
        end
        put '/:id' do
          cloud = ::Cloud.find(params[:id])
          authorize!(:update, cloud)
          cloud.update_attributes!(declared_params)
          cloud
        end

        desc 'Destroy cloud'
        params do
          requires :id, type: Integer, desc: 'Cloud id'
        end
        delete '/:id' do
          cloud = ::Cloud.find(params[:id])
          authorize!(:destroy, cloud)
          cloud.destroy
          status 204
        end
      end
    end
  end
end
