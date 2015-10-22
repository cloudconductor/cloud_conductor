class Catalog < ActiveRecord::Base
  belongs_to :blueprint, inverse_of: :catalogs
  belongs_to :pattern

  validates_presence_of :blueprint, :pattern

  after_initialize do
    self.os_version ||= 'default'
  end
end
