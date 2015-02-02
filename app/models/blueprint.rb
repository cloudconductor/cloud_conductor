class Blueprint < ActiveRecord::Base
  belongs_to :project
  has_many :patterns, dependent: :destroy

  validates :name, presence: true
end
