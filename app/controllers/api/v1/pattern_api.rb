module API
  module V1
    class PatternAPI < API::V1::Base
      resource :patterns do
        desc 'List patterns'
        get '/' do
          authorize!(:read, ::Pattern)
          ::Pattern.all.select do |pattern|
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
          requires :url, type: String, desc: 'Pattern repository url'
          requires :revision, type: String, desc: 'Pattern repository revision'
        end
        post '/' do
          authorize!(:create, ::Pattern)
          body ::Pattern.create!(declared_params)
          status 201
        end

        desc 'Update pattern'
        params do
          requires :id, type: Integer, desc: 'Pattern id'
          optional :url, type: String, desc: 'Pattern repository url'
          optional :revision, type: String, desc: 'Pattern repository revision'
        end
        put '/:id' do
          pattern = ::Pattern.find(params[:id])
          authorize!(:update, pattern)
          pattern.update_attributes!(declared_params)
          status 201
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
