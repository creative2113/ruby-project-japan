require "administrate/base_dashboard"

class BillingPlanDashboard < Administrate::BaseDashboard
  # ATTRIBUTE_TYPES
  # a hash that describes the type of each of the model's fields.
  #
  # Each different type represents an Administrate::Field object,
  # which determines how the attribute is displayed
  # on pages throughout the dashboard.
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    billing: Field::BelongsTo,
    charge_date: Field::String,
    end_at: Field::DateTime,
    last_charge_date: Field::Date,
    memo: Field::Text,
    name: Field::String,
    next_charge_date: Field::Date,
    price: Field::Number,
    start_at: Field::DateTime,
    status: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
    tax_included: Field::Boolean,
    tax_rate: Field::Number,
    trial: Field::Boolean,
    type: Field::Select.with_options(searchable: false, collection: ->(field) { field.resource.class.send(field.attribute.to_s.pluralize).keys }),
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
    billing
    name
    type
    price
    start_at
    end_at
    charge_date
    next_charge_date
  ].freeze

  # SHOW_PAGE_ATTRIBUTES
  # an array of attributes that will be displayed on the model's show page.
  SHOW_PAGE_ATTRIBUTES = %i[
    id
    billing
    charge_date
    end_at
    last_charge_date
    memo
    name
    next_charge_date
    price
    start_at
    status
    tax_included
    tax_rate
    trial
    type
    created_at
    updated_at
  ].freeze

  # FORM_ATTRIBUTES
  # an array of attributes that will be displayed
  # on the model's form (`new` and `edit`) pages.
  FORM_ATTRIBUTES = %i[
    billing
    charge_date
    end_at
    last_charge_date
    memo
    name
    next_charge_date
    price
    start_at
    status
    tax_included
    tax_rate
    trial
    type
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

  # Overwrite this method to customize how billing plans are displayed
  # across all pages of the admin dashboard.
  #
  # def display_resource(billing_plan)
  #   "BillingPlan ##{billing_plan.id}"
  # end
end
