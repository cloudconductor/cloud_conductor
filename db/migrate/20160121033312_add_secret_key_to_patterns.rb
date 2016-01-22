class AddSecretKeyToPatterns < ActiveRecord::Migration
  def change
    add_column :patterns, :secret_key, :text
  end
end
