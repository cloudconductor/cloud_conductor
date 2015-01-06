class AddConsulSecurityKeyToPatterns < ActiveRecord::Migration
  def change
    add_column :patterns, :consul_security_key, :string
  end
end
