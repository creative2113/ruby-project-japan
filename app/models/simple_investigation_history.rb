class SimpleInvestigationHistory < ApplicationRecord
  belongs_to :request
  belongs_to :user

  validates :url, presence: true
end
