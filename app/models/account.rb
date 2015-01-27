class Account < ActiveRecord::Base
  has_many :assignments
  has_many :projects, through: :assignments

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :token_authenticatable

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  # validates :admin, inclusion: { in: [true, false] }

  BLACKLIST_FOR_SERIALIZATION << :authentication_token

  def display_name
    email
  end
end
