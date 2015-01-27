class OperatingSystem < ActiveRecord::Base
  validates :name, presence: true, format: /\A[^\-]+\Z/

  def self.candidates(supports)
    (supports || []).map do |support|
      fail "version supports only '= 1.2' format currently" unless support[:version] =~ /^=\s*([\d.]+)$/
      name = support[:os]
      version = Regexp.last_match[1]
      OperatingSystem.where(name: name, version: version)
    end.flatten
  end
end
