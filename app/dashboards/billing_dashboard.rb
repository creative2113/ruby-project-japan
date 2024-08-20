require "administrate/base_dashboard"

class BillingDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    customer_id: Field::String,
    expiration_date: Field::DateTime,
    first_paid_at: Field::DateTime,
    last_paid_at: Field::DateTime,
    last_plan: Field::Number,
    next_plan: Field::Number,
    payment_method: Field::String,
    plan: Field::Number,
    status: Field::String,
    strange: Field::Boolean,
    subscription_id: Field::String,
    user: Field::BelongsTo,
    plans: Field::HasMany,
    histories: Field::HasMany,
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
    customer_id
    expiration_date
    first_paid_at
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    customer_id
    expiration_date
    first_paid_at
    last_paid_at
    last_plan
    next_plan
    payment_method
    plan
    status
    strange
    subscription_id
    user
    plans
    histories
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    customer_id
    expiration_date
    first_paid_at
    last_paid_at
    last_plan
    next_plan
    payment_method
    plan
    status
    strange
    subscription_id
    user
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

  # Overwrite this method to customize how billings are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(billing)
  #   "Billing ##{billing.id}"
  # end
end
