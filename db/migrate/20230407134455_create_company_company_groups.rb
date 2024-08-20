class CreateCompanyCompanyGroups < ActiveRecord::Migration[6.1]
  def change
    create_table :company_company_groups do |t|
      t.bigint :company_id,       null:false
      t.bigint :company_group_id, null: false

      t.timestamps
    end

    add_index :company_company_groups, [:company_id, :company_group_id], unique: true, name: 'index_company_and_company_group'
  end
end
