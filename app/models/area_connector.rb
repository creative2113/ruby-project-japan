class AreaConnector < ApplicationRecord
  belongs_to :region
  belongs_to :prefecture, optional: true
  belongs_to :city, optional: true
  has_many :company_area_connectors
  has_many :companys, through: :company_area_connectors

  validates :region_id, uniqueness: { scope: [:prefecture_id, :city_id] }
  validate :check_blank

  AREAS = {
    '北海道・東北' => ['北海道','青森県','秋田県','山形県','岩手県','宮城県','福島県'],
    '関東' => ['栃木県','茨城県','群馬県','埼玉県','千葉県','東京都','神奈川県'],
    '北陸・甲信越' => ['新潟県','富山県','石川県','福井県','山梨県','長野県'],
    '東海' => ['岐阜県','静岡県','愛知県','三重県'],
    '近畿' => ['滋賀県','京都府','大阪府','兵庫県','奈良県','和歌山県'],
    '中国' => ['鳥取県','島根県','岡山県','広島県','山口県'],
    '四国' => ['徳島県','香川県','愛媛県','高知県'],
    '九州・沖縄' => ['福岡県','佐賀県','長崎県','熊本県','大分県','宮崎県','鹿児島県','沖縄県']
  }.freeze

  private

  def check_blank
    if city_id.present?
      errors.add(:region_id, "は存在しません。") if region_id.blank?
      errors.add(:prefecture_id, "は存在しません。") if prefecture_id.blank?
    elsif prefecture_id.present?
      errors.add(:region_id, "は存在しません。") if region_id.blank?
    end
  end

  class << self

    def select_region_from_prefecture(prefecture)
    end

    def import_and_make(company, region, prefecture, city)
    end

    def areas_str(ids)
    end

    def find_or_create(region, prefecture, city)
    end

    def make_where_clause(connector_ids)
    end

    def find_all_area_comb
    end
  end
end
