module API
  module V1
    class PatternAPI < API::V1::Base
      resource :patterns do
        before do
          temp = current_project(Pattern)
          @project_id = nil
          @project_id = temp.id if temp
        end

        after do
          track_api(@project_id)
        end

        desc 'List patterns'
        params do
          optional :project_id, type: Integer, desc: 'Project id'
        end
        get '/' do
          ::Pattern.where(params.slice(:project_id).to_hash).select do |pattern|
            can?(:read, pattern)
          end
        end

        desc 'Show pattern'
        params do
          requires :id, type: Integer, desc: 'Pattern id'
        end
        get '/:id' do
          pattern = ::Pattern.find(params[:id])
          authorize!(:read, pattern)
          pattern
        end

        desc 'Create pattern'
        params do
          requires :project_id, type: Integer, exists_id: :project, desc: 'Project id'
          requires :url, type: String, desc: 'URL of repository that contains pattern'
          optional :revision, type: String, desc: 'revision of repository'
          optional :secret_key, type: String, desc: 'secret_key for private repository'
        end
        post '/' do
          project = ::Project.find_by(id: params[:project_id])
          authorize!(:read, project)
          authorize!(:create, ::Pattern, project: project)
          ::Pattern.create!(declared_params)
        end

        desc 'Update pattern'
        params do
          optional :url, type: String, desc: 'URL of repository that contains pattern'
          optional :revision, type: String, desc: 'revision of repository'
          optional :secret_key, type: String, desc: 'secret_key for private repository'
        end
        put '/:id' do
          pattern = ::Pattern.find(params[:id])
          authorize!(:update, pattern)
          pattern.update_attributes!(declared_params)
          pattern
        end

        desc 'Destroy pattern'
        params do
          requires :id, type: Integer, desc: 'Pattern id'
        end
        delete '/:id' do
          pattern = ::Pattern.find(params[:id])
          authorize!(:destroy, pattern)
          pattern.destroy
          status 204
        end
      end
    end
  end
end
