class MasterBillingPlan < ApplicationRecord
  self.inheritance_column = :_type_disabled # typeを使えるようにする

  enum type: [:dayly, :weekly, :monthly, :quarterly, :annually]

  validates :start_at, presence: true
  validates :type, presence: true

  scope :enabled, -> (time = Time.zone.now) do
    where(enable: true).where('( start_at <= ? AND ? <= end_at ) OR ( start_at <= ? AND end_at IS NULL )', time, time, time)
  end

  scope :application_enabled, -> (time = Time.zone.now) do
    enabled.where(application_available: true).where('( application_start_at <= ? AND ? <= application_end_at ) OR ( application_start_at <= ? AND application_end_at IS NULL )', time, time, time)
  end

  def select_box_name
    "#{name}(#{id}) #{price.to_s(:delimited)}円"
  end
end
