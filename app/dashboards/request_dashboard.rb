require "administrate/base_dashboard"

class RequestDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    accept_id: Field::String,
    accessed_urls: Field::Text,
    company_info_result_headers: Field::Text,
    complete_multi_path_analysis: Field::Boolean,
    corporate_individual_config: Field::Text,
    corporate_list_config: Field::Text,
    corporate_list_site_start_url: Field::String,
    excel: Field::String,
    expiration_date: Field::Date,
    file_name: Field::String,
    free_search: Field::Boolean,
    ip: Field::String,
    link_words: Field::String,
    list_site_analysis_result: Field::Text,
    list_site_result_headers: Field::Text,
    mail_address: Field::String,
    multi_path_analysis: Field::Text,
    multi_path_candidates: Field::Text,
    paging_mode: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    requested_urls: Field::HasMany,
    requested_urls_count: Field::Number,
    result_file_path: Field::String,
    status: Field::Number,
    target_words: Field::String,
    test: Field::Boolean,
    title: Field::String,
    tmp_company_info_urls: Field::HasMany,
    token: Field::String,
    type: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    unnecessary_company_info: Field::Boolean,
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
    user
    accept_id
    type
    test
    corporate_list_site_start_url
    file_name
    title
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    accept_id
    user
    title
    corporate_list_site_start_url
    file_name
    test
    mail_address
    expiration_date
    accessed_urls
    company_info_result_headers
    complete_multi_path_analysis
    corporate_individual_config
    corporate_list_config
    excel
    free_search
    ip
    link_words
    list_site_analysis_result
    list_site_result_headers
    multi_path_analysis
    multi_path_candidates
    paging_mode
    requested_urls
    requested_urls_count
    result_file_path
    status
    target_words
    title
    tmp_company_info_urls
    token
    type
    unnecessary_company_info
    use_storage
    using_storage_days
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    id
    accept_id
    user
    title
    corporate_list_site_start_url
    file_name
    test
    mail_address
    expiration_date
    accessed_urls
    company_info_result_headers
    complete_multi_path_analysis
    corporate_individual_config
    corporate_list_config
    excel
    free_search
    ip
    link_words
    list_site_analysis_result
    list_site_result_headers
    multi_path_analysis
    multi_path_candidates
    paging_mode
    result_file_path
    status
    target_words
    title
    tmp_company_info_urls
    token
    type
    unnecessary_company_info
    use_storage
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

  # Overwrite this method to customize how requests are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(request)
  #   "Request ##{request.id}"
  # end
end
