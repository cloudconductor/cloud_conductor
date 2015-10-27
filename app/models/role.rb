class Role < ActiveRecord::Base
  belongs_to :project

  validates_presence_of :name, :project

  validates :name, uniqueness: { scope: :project_id }
end
