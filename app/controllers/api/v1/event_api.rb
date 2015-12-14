module API
  module V1
    class EventAPI < API::V1::Base
      resource :environments do
        before do
          @project_id = nil
          if request.params.key?(:project_id)
            @project_id = request.params[:project_id]
          end

          if request.params.key?(:system_id)
            system_id = request.params[:system_id]
            system = System.find_by_id(system_id)
            @project_id = system.project_id if system
          end

          if request.params.key?(:id)
            environment = Environment.find_by_id(request.params[:id])
            system_id = environment.system_id if environment
            system = System.find_by_id(system_id)
            @project_id = system.project_id if system
          end
        end

        after do
          track_api(@project_id)
        end

        desc 'List events'
        params do
          requires :id, type: Integer, desc: 'Environment id'
        end
        get '/:id/events' do
          environment = ::Environment.find(declared_params[:id])
          authorize!(:read, environment)

          environment.event.list
        end

        desc 'Show event'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          requires :event_id, type: String, desc: 'Event id'
        end
        get '/:id/events/:event_id' do
          environment = ::Environment.find(declared_params[:id])
          authorize!(:read, environment)
          event = environment.event.find(declared_params[:event_id])
          if event
            event.as_json(detail: true)
          else
            status 404
            { error: "Couldn't find Event with 'event-id'=#{declared_params[:event_id]}" }
          end
        end

        desc 'Fire event'
        params do
          requires :id, type: Integer, desc: 'Environment id'
          requires :event, type: String, desc: 'Event name'
        end
        post '/:id/events' do
          environment = ::Environment.find(declared_params[:id])
          authorize!(:update, environment)

          event_id = environment.event.fire(declared_params[:event])
          status 202
          { event_id: event_id }
        end
      end
    end
  end
end
