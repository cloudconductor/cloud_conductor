class Blueprint < ActiveRecord::Base
  belongs_to :project
  has_many :patterns, through: :blueprint_patterns
  has_many :blueprint_patterns, dependent: :destroy, inverse_of: :blueprint
  has_many :histories, class_name: :BlueprintHistory, dependent: :destroy

  validates_presence_of :name, :project
  validates :name, uniqueness: true

  def can_build?
    patterns.any? { |pattern| pattern.type == 'platform' }
  end
end
