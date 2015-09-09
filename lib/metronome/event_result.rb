module Metronome
  class EventResult
    attr_accessor :id, :name, :status, :started_at, :finished_at
    def self.list(client)
      entries = client.kv.get('metronome/results', true)
      (entries || []).select { |k, _| k =~ %r{^metronome/results/[a-z0-9-]+$} }.map do |_, v|
        EventResult.new(client, v)
      end
    end

    def self.find(client, id)
      json = client.kv.get("metronome/results/#{id}")
      EventResult.new(client, json) if json
    end

    def initialize(client, hash)
      @client = client
      self.id = hash['ID']
      self.name = hash['Name']
      self.status = hash['Status'].to_sym
      self.started_at = DateTime.parse(hash['StartedAt']) if hash['StartedAt']
      self.finished_at = DateTime.parse(hash['FinishedAt']) if hash['FinishedAt']
    end

    def finished?
      [:success, :error, :timeout].include? status
    end

    def success?
      status == :success
    end

    def as_json(options = {})
      options[:except] ||= []
      options[:except] = [options[:except], 'client'].flatten
      super
    end

    def task_results
      return @task_results if @task_results
      @task_results = TaskResult.list(@client, id)
    end

    def refresh!
      @task_results = TaskResult.list(@client, id)
      @task_results.each(&:refresh!)
      self
    end
  end
end
