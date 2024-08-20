class CreateCompanyCategoryConnectors < ActiveRecord::Migration[6.1]
  def change
    create_table :company_category_connectors do |t|
      t.bigint :company_id
      t.bigint :category_connector_id

      t.timestamps
    end

    add_index :company_category_connectors, [:company_id, :category_connector_id], unique: true, name: 'index_company_and_category_connector'
  end
end
