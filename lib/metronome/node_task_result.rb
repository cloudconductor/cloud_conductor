module Metronome
  class NodeTaskResult
    attr_accessor :id, :no, :node, :status, :started_at, :finished_at, :log
    def self.list(client, id, no)
      entries = client.kv.get("metronome/results/#{id}/#{no}", true)
      (entries || []).select { |k, _| k =~ %r{^metronome/results/[a-z0-9-]+/\d+/[^/]+$} }.map do |k, v|
        log = entries["#{k}/log"]
        NodeTaskResult.new(client, v, log)
      end
    end

    def self.find(client, id, no, node)
      json = client.kv.get("metronome/results/#{id}/#{no}/#{node}")
      log = client.kv.get("metronome/results/#{id}/#{no}/#{node}/log")
      NodeTaskResult.new(client, json, log) if json
    end

    def initialize(client, hash, log)
      @client = client

      self.id = hash['EventID']
      self.no = hash['No']
      self.node = hash['Node']
      self.status = hash['Status'].to_sym
      self.started_at = DateTime.parse(hash['StartedAt']) if hash['StartedAt']
      self.finished_at = DateTime.parse(hash['FinishedAt']) if hash['FinishedAt']
      self.log = log.force_encoding('UTF-8')
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
  end
end
