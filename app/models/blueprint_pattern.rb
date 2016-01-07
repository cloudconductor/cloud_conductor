class BlueprintPattern < ActiveRecord::Base
  belongs_to :blueprint, inverse_of: :blueprint_patterns
  belongs_to :pattern

  validates_presence_of :blueprint, :pattern, :platform
  validate do
    errors.add(:platform, 'is invalid') if platform && !Platform.family(platform)
  end

  def project
    blueprint.project
  end
end
