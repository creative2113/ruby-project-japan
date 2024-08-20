class Notice < ApplicationRecord
  scope :opened, -> { where(opened_at: (Time.zone.today - 1.year)..Time.zone.today, display: true).order(opened_at: :desc) }
  scope :view_top, -> { where(top_page: true) }
end
