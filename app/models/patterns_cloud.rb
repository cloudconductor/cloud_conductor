class PatternsCloud < ActiveRecord::Base
  belongs_to :pattern
  belongs_to :cloud

  validates_associated :pattern, :cloud
end
