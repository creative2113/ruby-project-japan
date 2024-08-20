class CompanyAreaConnector < ApplicationRecord
  belongs_to :company
  belongs_to :area_connector
end
