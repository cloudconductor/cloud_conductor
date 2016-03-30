class AddSecretKeyToPatternSnapshots < ActiveRecord::Migration
  def change
    add_column :pattern_snapshots, :secret_key, :text
  end
end
