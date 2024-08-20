class CompanyGroupConstraint

  class DuplicatedGroupIDHeaders < StandardError; end

  class NotPositiveIntegerGroupID < StandardError; end

  class NotFoundGroupID < StandardError; end

  class DifferentGroupID < StandardError; end

  class BlankGroupID < StandardError; end

  class StrangeGroupID < StandardError; end

  class SameTitleButDifferentGroupingID < StandardError; end

  def initialize(all_headers)

    raise DuplicatedGroupIDHeaders, '重複しているグループIDが存在しています。' unless correct_group_id_header?(all_headers)

    @headers = select_group_id_headers(all_headers)

    @headers_map = @headers.map { |h| [h, nil] }.to_h
  end

  def check(row_data)
    row_data.each { |header, id| group_id_header?(header) && correct?(header, id) }
  end

  def select_group_ids(row_data)
    check(row_data)

    map = []
    row_data.each do |header, id|
      map << id.to_i if group_id_header?(header) && id.present?
    end
    map
  end

  private

  def correct?(header, group_id)
    raise StrangeGroupID, "#{header}のグループIDは奇妙なIDです。文字列で渡されませんでした。#{group_id}" unless group_id.class == String
    raise BlankGroupID, "#{header}のグループIDが空欄です。空欄を許可するにはヘッダーに「空欄許可」を加えてください。" if !header.include?('空欄許可') && group_id.blank?
    raise NotPositiveIntegerGroupID, "#{header}：グループIDは正の整数でなければいけません。#{group_id}" if group_id.present? && ( group_id.to_i.to_s != group_id || group_id.to_i < 0 )

    return true if group_id.blank?

    if @headers_map[header].nil?
      group = CompanyGroup.find_by(id: group_id)
      raise NotFoundGroupID, "#{header}のグループIDは存在しないIDです。#{group_id}" if group.blank?

      @headers_map[header] = { group: group, same_group_ids: find_same_group(group) }
      return true
    end

    return true if @headers_map[header][:group].id == group_id.to_i ||
                   @headers_map[header][:same_group_ids].include?(group_id.to_i)

    raise NotFoundGroupID, "#{header}のグループIDは存在しないIDです。#{group_id}" if CompanyGroup.find_by(id: group_id).blank?
    raise DifferentGroupID, "#{header}のグループIDは違うグループのIDです。#{group_id}"
  end

  # same_groupのルール
  #   1. grouping_numberが同じなら、タイトルは違ってもOK
  #   2. タイトルもサブタイトルも同じなら、grouping_numberも同じでないといけない
  def find_same_group(group_instance)
    CompanyGroup.where(grouping_number: group_instance.grouping_number).pluck(:id).uniq.sort
  end

  def select_group_id_headers(all_headers)
    all_headers.select { |h| group_id_header?(h) }
  end

  def group_id_header?(header)
    header.start_with?('グループID_') || header == 'グループID'
  end

  def correct_group_id_header?(all_headers)
    group_id_headers = all_headers.select { |h| group_id_header?(h) }
    group_id_headers.size == group_id_headers.uniq.size
  end
end
