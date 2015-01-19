class AddConsulSecretKeyToPatterns < ActiveRecord::Migration
  def change
    add_column :patterns, :consul_secret_key, :string
  end
end
