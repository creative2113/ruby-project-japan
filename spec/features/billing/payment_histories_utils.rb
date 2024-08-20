def check_billing_data_row_in_payment_histories_page(row_num, data_history = nil)
  if row_num == 1
    within 'table tbody tr:first-child' do
      expect(page).to have_content '課金日'
      expect(page).to have_content '項目名'
      expect(page).to have_content '支払方法'
      expect(page).to have_content '単価'
      expect(page).to have_content '個数'
      expect(page).to have_content '金額'
    end
  else
    within "table tbody tr:nth-child(#{row_num})" do
      expect(page).to have_selector('td:nth-child(1)', text: data_history.billing_date.strftime("%Y年%-m月%-d日"))
      expect(page).to have_selector('td:nth-child(2)', text: data_history.item_name)
      expect(page).to have_selector('td:nth-child(3)', text: data_history.payment_method_str)
      expect(page).to have_selector('td:nth-child(4)', text: "#{data_history.unit_price.to_s(:delimited)}円")
      expect(page).to have_selector('td:nth-child(5)', text: "#{data_history.number.to_s(:delimited)}")
      expect(page).to have_selector('td:nth-child(6)', text: "#{data_history.price.to_s(:delimited)}円")
    end
  end
end
