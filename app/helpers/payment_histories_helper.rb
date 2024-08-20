module PaymentHistoriesHelper

  def convert_month_to_number(month_str)
    year = month_str.split('年')[0]
    month = month_str.split('年')[1].gsub('月', '')
    month = "0#{month}" if month.length == 1
    "#{year}#{month}"
  end
end
