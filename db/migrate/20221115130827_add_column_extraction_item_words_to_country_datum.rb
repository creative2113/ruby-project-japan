class AddColumnExtractionItemWordsToCountryDatum < ActiveRecord::Migration[6.1]
  def change
    add_column :country_data, :extraction_item_words, :text, after: :indicators
  end
end
