class CreateAudits < ActiveRecord::Migration
  def change
    create_table :audits do |t|
      t.string :ip
      t.string :account
      t.string :status
      t.string :request

      t.timestamps null: false
    end
  end
end
