require "administrate/base_dashboard"

class CategoryConnectorDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    companys: Field::HasMany,
    count: Field::Number,
    detail_category: Field::BelongsTo,
    large_category: Field::BelongsTo,
    middle_category: Field::BelongsTo,
    small_category: Field::BelongsTo,
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
    large_category
    middle_category
    small_category
    detail_category
    companys
    count
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    companys
    count
    large_category
    middle_category
    small_category
    detail_category
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    companys
    count
    large_category
    middle_category
    small_category
    detail_category
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

  # Overwrite this method to customize how category connectors are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(category_connector)
    "Connector ##{category_connector.id} #{category_connector.large_category&.name} #{category_connector.middle_category&.name} #{category_connector.small_category&.name}  #{category_connector.detail_category&.name}"
  end
end
