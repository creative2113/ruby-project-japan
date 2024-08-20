module RequestsHelper
  include Pagy::Frontend

  def excel_row_limit
    if user_signed_in?
      EasySettings.excel_row_limit[current_user.my_plan]
    else
      EasySettings.excel_row_limit[:public]
    end
  end

  def execution_type(test)
    test ? 'テスト実行' : '本実行'
  end

  def storage_days(days)
    days.present? ? "#{days}日前まで" : '期限なし'
  end

  def display_test_result(content)
    return [''] if content.blank?
    content = content.join(' ') if content.class == Array
    content = content.split('; ').map do |con|
      if con[0..6] == 'http://' || con[0..7] == 'https://'
        link_to con, con, target: :_blank
      elsif con.include?('(') && con.include?(')') && con.include?('http')
        make_url_link_array(con)
      else
        con
      end
    end
    content
  end

  def paging_mode(request)
    if request.only_this_page?
      'このページのみから収集する'
    elsif request.only_paging?
      'ページ送りのみ行う'
    else
      '指定しない'
    end
  end

  def dl_status(status)
    case status
    when 'completed'
      '作成完了'
    when 'error'
      'エラー'
    else
      '作成中'
    end
  end

  private

  def make_url_link_array(text)
    text2 = text.split('(')[-1].split(')')[0]
    if text2[0..6] == 'http://' || text2[0..7] == 'https://'
      [text.split('(http')[0] + '(', link_to(text2, text2, target: :_blank, rel: 'noopener noreferrer'), ')']
    else
      text
    end
  end
end
