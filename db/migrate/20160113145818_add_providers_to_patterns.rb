class AddProvidersToPatterns < ActiveRecord::Migration
  def change
    add_column :patterns, :providers, :string
    add_column :pattern_snapshots, :providers, :string
  end
end
