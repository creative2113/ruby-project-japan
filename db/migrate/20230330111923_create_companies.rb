class CreateCompanies < ActiveRecord::Migration[6.1]
  def change
    create_table :companies do |t|
      t.string :domain, index: { unique: true }, null: false

      t.timestamps
    end
  end
end
