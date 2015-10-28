class BlueprintPattern < ActiveRecord::Base
  belongs_to :blueprint, inverse_of: :blueprint_patterns
  belongs_to :pattern

  validates_presence_of :blueprint, :pattern

  after_initialize do
    self.os_version ||= 'default'
  end
end
