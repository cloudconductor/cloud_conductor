class Permission < ActiveRecord::Base
  belongs_to :role

  validates_associated :role
  validates_presence_of :role, :model, :action

  validates :action, inclusion: { in: %w(manage read create update destroy) }, uniqueness: { scope: [:role_id, :model] }
  validates :model, inclusion: { in: %w(project assignment account role permission cloud base_image pattern blueprint blueprint_pattern blueprint_history system environment application application_history deployment) } # rubocop:disable Metrics/LineLength
end
