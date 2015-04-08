class ChangeDataTypeForScriptOnApplicationHistories < ActiveRecord::Migration
  def change
    change_column :application_histories, :pre_deploy, :text
    change_column :application_histories, :post_deploy, :text
  end
end
