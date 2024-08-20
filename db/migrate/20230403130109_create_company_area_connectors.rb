class CreateCompanyAreaConnectors < ActiveRecord::Migration[6.1]
  def change
    create_table :company_area_connectors do |t|
      t.bigint :company_id
      t.bigint :area_connector_id

      t.timestamps
    end

    add_index :company_area_connectors, [:company_id, :area_connector_id], unique: true, name: 'index_company_and_area_connector'
  end
end
