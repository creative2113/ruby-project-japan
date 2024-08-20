class CreateCountryData < ActiveRecord::Migration[5.2]
  def change
    create_table :country_data do |t|
      t.string  :name,               index: true
      t.string  :japanese_name,      index: true
      t.string  :language
      t.text    :areas
      t.integer :country_code
      t.integer :tel_number_max_size
      t.integer :tel_number_min_size
      t.integer :post_code_max_size
      t.integer :post_code_min_size
      t.string  :post_code_regexps
      t.string  :search_words
      t.string  :company_names
      t.text    :organization_words
      t.string  :address_words
      t.string  :post_code_words
      t.string  :tel_words
      t.string  :fax_words
      t.string  :contact_words
      t.string  :requested_url
      t.text    :indicate_words
      t.text    :indicators

      t.timestamps
    end
  end
end
