require "administrate/base_dashboard"

class UserDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    billing: Field::HasOne,
    role: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    preferences: Field::HasOne,
    monthly_histories: Field::HasMany,
    company_name: Field::String,
    family_name: Field::String,
    given_name: Field::String,
    department: Field::String,
    position: Field::String,
    address: Field::String,
    tel: Field::String,
    confirmation_sent_at: Field::DateTime,
    confirmation_token: Field::String,
    confirmed_at: Field::DateTime,
    current_sign_in_at: Field::DateTime,
    current_sign_in_ip: Field::String,
    email: Field::String,
    # encrypted_password: Field::String,
    failed_attempts: Field::Number,
    language: Field::String,
    last_request_count: Field::Number,
    last_request_date: Field::Date,
    last_search_count: Field::Number,
    last_sign_in_at: Field::DateTime,
    last_sign_in_ip: Field::String,
    latest_access_date: Field::Date,
    locked_at: Field::DateTime,
    referrer: Field::BelongsTo,
    remember_created_at: Field::DateTime,
    request_count: Field::Number,
    requests: Field::HasMany,
    reset_password_sent_at: Field::DateTime,
    reset_password_token: Field::String,
    search_count: Field::Number,
    search_requests: Field::HasMany,
    sign_in_count: Field::Number,
    terms_of_service: Field::Boolean,
    unconfirmed_email: Field::String,
    unlock_token: Field::String,
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
    email
    company_name
    family_name
    given_name
    confirmation_sent_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    role
    email
    company_name
    family_name
    given_name
    department
    position
    tel
    confirmation_sent_at
    confirmation_token
    confirmed_at
    current_sign_in_at
    current_sign_in_ip
    failed_attempts
    language
    preferences
    billing
    monthly_histories
    last_request_count
    last_request_date
    last_search_count
    last_sign_in_at
    last_sign_in_ip
    latest_access_date
    locked_at
    referrer
    remember_created_at
    request_count
    requests
    reset_password_sent_at
    reset_password_token
    search_count
    search_requests
    sign_in_count
    terms_of_service
    unconfirmed_email
    unlock_token
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    role
    email
    company_name
    family_name
    given_name
    department
    position
    tel
    confirmation_sent_at
    confirmation_token
    confirmed_at
    current_sign_in_at
    current_sign_in_ip
    failed_attempts
    language
    last_request_count
    last_request_date
    last_search_count
    last_sign_in_at
    last_sign_in_ip
    latest_access_date
    locked_at
    referrer
    remember_created_at
    request_count
    requests
    reset_password_sent_at
    reset_password_token
    search_count
    search_requests
    sign_in_count
    terms_of_service
    unconfirmed_email
    unlock_token
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

  # Overwrite this method to customize how users are displayed
  # across all pages of the admin dashboard.
  #
  def display_resource(user)
    "##{user.id} #{user.company_name[0..25]} #{user.email[0..25]}"
  end
end
