class City < ApplicationRecord
  has_many :area_connectors

  def self.find_or_create(name)
    res = self.find_by(name: name)
    res = self.create!(name: name) if res.blank?
    res
  end
end