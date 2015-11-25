class Account < ActiveRecord::Base
  has_many :assignments, dependent: :destroy
  has_many :projects, through: :assignments
  accepts_nested_attributes_for :assignments, allow_destroy: true

  # Include default devise modules. Others available are:
  # :registerable, :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable,
         :recoverable, :rememberable, :trackable, :validatable,
         :token_authenticatable

  validates_presence_of :email, :name
  validates :email, uniqueness: { case_sensitive: false }

  before_create :ensure_authentication_token

  BLACKLIST_FOR_SERIALIZATION << :authentication_token

  scope :assigned_to, -> (project_id) { joins(:assignments).where(assignments: { project_id: project_id }) }

  def display_name
    email
  end

  private

  def password_required?
    new_record? ? super : false
  end
end
