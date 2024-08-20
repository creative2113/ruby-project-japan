class CompanyCategoryConnector < ApplicationRecord
  belongs_to :company
  belongs_to :category_connector
end
