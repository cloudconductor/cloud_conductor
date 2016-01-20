class AddTemplateParametersToEnvironment < ActiveRecord::Migration
  def change
    add_column :environments, :template_parameters, :text
  end
end
