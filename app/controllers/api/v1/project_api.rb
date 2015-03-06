module API
  module V1
    class ProjectAPI < API::V1::Base
      resource :projects do
        desc 'List projects'
        get '/' do
          authorize!(:read, ::Project)
          ::Project.all
        end

        desc 'Show project'
        params do
          requires :id, type: Integer, desc: 'Project id'
        end
        get '/:id' do
          project = ::Project.find(params[:id])
          authorize!(:read, project)
          project
        end

        desc 'Create project'
        params do
          requires :name, type: String, desc: 'Project name'
          optional :description, type: String, desc: 'Project description'
        end
        post '/' do
          authorize!(:create, ::Project)
          parameters = declared_params.merge(current_account: current_account)
          ::Project.create!(parameters)
        end

        desc 'Update project'
        params do
          requires :id, type: Integer, desc: 'Project id'
          optional :name, type: String, desc: 'Project name'
          optional :description, type: String, desc: 'Project description'
        end
        put '/:id' do
          project = ::Project.find(params[:id])
          authorize!(:update, project)
          project.update_attributes!(declared_params)
          project
        end

        desc 'Destroy project'
        params do
          requires :id, type: Integer, desc: 'Project id'
        end
        delete '/:id' do
          project = ::Project.find(params[:id])
          authorize!(:destroy, project)
          project.destroy
          status 204
        end
      end
    end
  end
end
