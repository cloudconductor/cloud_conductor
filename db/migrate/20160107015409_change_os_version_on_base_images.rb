class ChangeOsVersionOnBaseImages < ActiveRecord::Migration
  def change
    remove_column :base_images, :os_version, :string
    add_column :base_images, :platform, :string
    add_column :base_images, :platform_version, :string

    remove_column :blueprint_patterns, :os_version, :string
    add_column :blueprint_patterns, :platform, :string
    add_column :blueprint_patterns, :platform_version, :string

    remove_column :pattern_snapshots, :os_version, :string
    add_column :pattern_snapshots, :platform, :string
    add_column :pattern_snapshots, :platform_version, :string
  end
end
