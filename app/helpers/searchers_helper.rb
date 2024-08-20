module SearchersHelper
  def convert_html_text(text)
    text.gsub(/\r\n|\r|\n/,'<br>').gsub(' ','&nbsp;').gsub(' ', '&emsp;')
  end

  def convert_url_text(text)
    return text unless text.include?('http')

    texts = text.split(', ').map do |str|
      if str[0..6] == 'http://' || str[0..7] == 'https://'
        link_to str, str, target: :_blank
      elsif str.include?('(') && str.include?(')') && str.include?('http')
        make_url_link_array(str)
      else
        str
      end
    end.flatten

    texts[-1] = texts[-1].chop.chop if texts[-1][-2..-1] == ', '
    texts
  end

  private

  def make_url_link_array(text)
    text2 = text.split('(')[-1].split(')')[0]
    if text2[0..6] == 'http://' || text2[0..7] == 'https://'
      [text.split('(http')[0] + '(', link_to(text2, text2, target: :_blank, rel: 'noopener noreferrer'), '), ']
    else
      text
    end
  end
end
