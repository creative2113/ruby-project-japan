class CategoryConnector < ApplicationRecord
  belongs_to :large_category
  belongs_to :middle_category, optional: true
  belongs_to :small_category, optional: true
  belongs_to :detail_category, optional: true
  has_many :company_category_connectors
  has_many :companys, through: :company_category_connectors

  validates :large_category_id, uniqueness: { scope: [:middle_category_id, :small_category_id, :detail_category_id] }
  validate :check_blank


  def category_str
    str = "#{self.large_category.name}"
    str += " > #{self.middle_category.name}" if self.middle_category.present?
    str += " > #{self.small_category.name}"  if self.small_category.present?
    str += " > #{self.detail_category.name}" if self.detail_category.present?
    str
  end

  private

  def check_blank
    if detail_category_id.present?
      errors.add(:large_category_id, "は存在しません。") if large_category_id.blank?
      errors.add(:middle_category_id, "は存在しません。") if middle_category_id.blank?
      errors.add(:small_category_id, "は存在しません。") if small_category_id.blank?
    elsif small_category_id.present?
      errors.add(:large_category_id, "は存在しません。") if large_category_id.blank?
      errors.add(:middle_category_id, "は存在しません。") if middle_category_id.blank?
    elsif middle_category_id.present?
      errors.add(:large_category_id, "は存在しません。") if large_category_id.blank?
    end
  end

  class << self

    def import_and_make(company, large, middle, small, detail)
    end

    def categories_str(ids)
    end

    def find_or_create(large, middle, small, detail)
    end

    def make_where_clause(connector_ids)
    end

    def find_all_category_comb
    end
  end
end
