require "administrate/base_dashboard"

class SearchRequestDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    accept_id: Field::String,
    domain: Field::Text,
    finish_status: Field::Number,
    free_search: Field::Boolean,
    free_search_result: Field::Text,
    link_words: Field::String,
    status: Field::Number,
    target_words: Field::String,
    url: Field::Text,
    use_storage: Field::Boolean,
    user: Field::BelongsTo,
    using_storage_days: Field::Number,
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
    accept_id
    domain
    finish_status
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    accept_id
    domain
    finish_status
    free_search
    free_search_result
    link_words
    status
    target_words
    url
    use_storage
    user
    using_storage_days
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    accept_id
    domain
    finish_status
    free_search
    free_search_result
    link_words
    status
    target_words
    url
    use_storage
    user
    using_storage_days
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

  # Overwrite this method to customize how search requests are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(search_request)
  #   "SearchRequest ##{search_request.id}"
  # end
end
