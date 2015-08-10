module Metronome
  class TaskResult
    attr_accessor :id, :no, :name, :status, :started_at, :finished_at
    def self.list(client, id)
      entries = client.kv.get("metronome/results/#{id}", true)
      (entries || []).select { |k, _| k =~ %r{^metronome/results/[a-z0-9-]+/\d+$} }.map do |_, v|
        TaskResult.new(client, v)
      end
    end

    def self.find(client, id, no)
      json = client.kv.get("metronome/results/#{id}/#{no}")
      TaskResult.new(client, json) if json
    end

    def initialize(client, hash)
      @client = client

      self.id = hash['EventID']
      self.no = hash['No']
      self.name = hash['Name']
      self.status = hash['Status'].to_sym
      self.started_at = DateTime.parse(hash['StartedAt']) if hash['StartedAt']
      self.finished_at = DateTime.parse(hash['FinishedAt']) if hash['FinishedAt']
    end

    def finished?
      [:success, :error].include? status
    end

    def success?
      status == :success
    end

    def as_json(options = {})
      options[:except] ||= []
      options[:except] = [options[:except], 'client'].flatten
      super
    end

    def nodes
      return @nodes if @nodes
      @nodes = NodeTaskResult.list(@client, id, no)
    end

    def refresh!
      @nodes = NodeTaskResult.list(@client, id, no)
      self
    end
  end
end
