class Blueprint < ActiveRecord::Base
  belongs_to :project
  has_many :patterns, dependent: :destroy, inverse_of: :blueprint
  accepts_nested_attributes_for :patterns

  validates_presence_of :name, :project, :patterns
end
