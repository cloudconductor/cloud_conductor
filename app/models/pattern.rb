class Pattern < ActiveRecord::Base
  include PatternAccessor
  self.inheritance_column = nil

  belongs_to :project
  has_many :blueprint_patterns, dependent: :destroy
  has_many :blueprints, through: :blueprint_patterns

  validates_presence_of :project
  validates :url, format: { with: URI.regexp }

  after_initialize do
    self.protocol ||= 'git'
  end

  before_save :update_metadata

  def as_json(options = {})
    super({ except: :parameters }.merge(options))
  end

  private

  def update_metadata
    clone_repository(url, revision) do |path|
      metadata = load_metadata(path)

      self.name = metadata[:name]
      self.type = metadata[:type]
      self.parameters = read_parameters(path).to_json
      self.roles = read_roles(path).to_json
    end
  end
end
