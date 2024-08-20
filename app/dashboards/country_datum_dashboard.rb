require "administrate/base_dashboard"

class CountryDatumDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    address_words: Field::String,
    areas: Field::Text,
    company_names: Field::String,
    contact_words: Field::String,
    country_code: Field::Number,
    extraction_item_words: Field::Text,
    fax_words: Field::String,
    indicate_words: Field::Text,
    indicators: Field::Text,
    japanese_name: Field::String,
    language: Field::String,
    name: Field::String,
    organization_words: Field::Text,
    post_code_max_size: Field::Number,
    post_code_min_size: Field::Number,
    post_code_regexps: Field::String,
    post_code_words: Field::String,
    requested_url: Field::String,
    search_words: Field::String,
    tel_number_max_size: Field::Number,
    tel_number_min_size: Field::Number,
    tel_words: Field::String,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
  }.freeze

  # COLLECTION_ATTRIBUTES
  # an array of attributes that will be displayed on the model's index page.
  #
  # By default, it's limited to four items to reduce clutter on index pages.
  # Feel free to add, remove, or rearrange items.
  COLLECTION_ATTRIBUTES = %i[
    id
    address_words
    areas
    company_names
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    address_words
    areas
    company_names
    contact_words
    country_code
    extraction_item_words
    fax_words
    indicate_words
    indicators
    japanese_name
    language
    name
    organization_words
    post_code_max_size
    post_code_min_size
    post_code_regexps
    post_code_words
    requested_url
    search_words
    tel_number_max_size
    tel_number_min_size
    tel_words
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    address_words
    areas
    company_names
    contact_words
    country_code
    extraction_item_words
    fax_words
    indicate_words
    indicators
    japanese_name
    language
    name
    organization_words
    post_code_max_size
    post_code_min_size
    post_code_regexps
    post_code_words
    requested_url
    search_words
    tel_number_max_size
    tel_number_min_size
    tel_words
  ].freeze

  # COLLECTION_FILTERS
  # a hash that defines filters that can be used while searching via the search
  # field of the dashboard.
  #
  # For example to add an option to search for open resources by typing "open:"
  # in the search field:
  #
  #   COLLECTION_FILTERS = {
  #     open: ->(resources) { resources.where(open: true) }
  #   }.freeze
  COLLECTION_FILTERS = {}.freeze

  # Overwrite this method to customize how country data are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(country_datum)
  #   "CountryDatum ##{country_datum.id}"
  # end
end
