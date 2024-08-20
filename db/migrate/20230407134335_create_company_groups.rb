class CreateCompanyGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :company_groups do |t|
      t.integer :type,     null: false
      t.integer :grouping_number
      t.string  :title,    null: false
      t.string  :subtitle
      t.string  :contents
      t.bigint  :upper
      t.bigint  :lower

      t.timestamps
    end
    add_index :company_groups, [:type, :grouping_number, :title]
  end
end
