
# 保存のフィールド出現確認
def confirm_storaged_data_field_operation(days: nil, from_close: true)
  if from_close
    find("span", text: '保存されているデータがあれば使う').click # Open
    expect(page).to have_selector('input#request_using_storage_days[type="text"]')
    expect(page).to have_content '日前の取得データなら使う'
  end

  expect(find_field('request_using_storage_days').value).to eq(days || '')

  find("span", text: '保存されているデータがあれば使う').click # Close
  expect(page).not_to have_selector('input#request_using_storage_days[type="text"]')
  expect(page).not_to have_content '日前の取得データなら使う'

  unless from_close
    find("span", text: '保存されているデータがあれば使う').click # Open
    expect(page).to have_selector('input#request_using_storage_days[type="text"]')
    expect(page).to have_content '日前の取得データなら使う'
  end
end

def confirm_top_crawle_config_toggle_button_operation
  find("h3", text: 'より正確にクロールするための詳細設定').click # Open
  expect(page).not_to have_selector('#detail_configuration_off', text: '設定なし')

  expect(page).to have_content '企業一覧ページの設定'
  expect(page).to have_selector('#corporate_list_config_off')
  expect(page).to have_selector('#corporate_list_config_off', text: '設定なし')
  expect(page).to have_content '企業個別ページの設定'
  expect(page).to have_selector('#corporate_individual_config_off')
  expect(page).to have_selector('#corporate_individual_config_off', text: '設定なし')

  find("h3", text: 'より正確にクロールするための詳細設定').click # Close
  expect(page).not_to have_content '企業一覧ページの設定'
  expect(page).not_to have_selector('#corporate_list_config_off')
  expect(page).not_to have_selector('#corporate_list_config_off', text: '設定なし')
  expect(page).not_to have_content '企業個別ページの設定'
  expect(page).not_to have_selector('#corporate_individual_config_off')
  expect(page).not_to have_selector('#corporate_individual_config_off', text: '設定なし')
end



#--------------------------
#
#   企業一覧ページの設定
#
#--------------------------
def confirm_corporate_list_page_config_operation
  find("h3", text: 'より正確にクロールするための詳細設定').click # Open

  find("h5", text: '企業一覧ページの設定').click # Open
  expect(page).not_to have_selector('#corporate_list_config_off', text: '設定なし')
  expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を開く')
  expect(page).to have_selector('div', text: '詳細設定なし')

  expect(page).not_to have_selector('input#request_corporate_list_1_organization_name_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_organization_name_1"]', text: '会社名1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_2_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_list_2_details_toggle_btn', text: '詳細設定を開く')

  expect(page).to have_selector('#add_corporate_list_url_config', text: '追加')
  expect(page).to have_selector('#remove_corporate_list_url_config.disabled', text: '削除')

  find("h5", text: '企業一覧ページの設定').click # Close

  expect(page).to have_selector('#corporate_list_config_off', text: '設定なし')
  expect(page).not_to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を開く')
  expect(page).not_to have_selector('div', text: '詳細設定なし')

  expect(page).not_to have_selector('#add_corporate_list_url_config', text: '追加')
  expect(page).not_to have_selector('#remove_corporate_list_url_config', text: '削除')

  find("h5", text: '企業一覧ページの設定').click # Open
  find('#corporate_list_1_details_toggle_btn', text: '詳細設定を開く').click # Open

  expect(page).not_to have_selector('div', text: '詳細設定なし')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる')
  expect(page).to have_selector('input#request_corporate_list_1_organization_name_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_organization_name_1"]', text: '会社名1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_organization_name_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_organization_name_2"]', text: '会社名2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_organization_name_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_organization_name_3"]', text: '会社名3 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_organization_name_4[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_organization_name_4"]', text: '会社名4 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_1_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_1_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_1_contents_1_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_1_text_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_1_text_2"]', text: 'サンプル文字2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_1_text_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_1_text_3"]', text: 'サンプル文字3 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_1_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_1_contents_2_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.add_corporate_list_url_contents_config', text: '追加')
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config.disabled', text: '削除')
  end

  find('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる').click # Close

  expect(page).to have_selector('div', text: '詳細設定なし')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を開く')
  expect(page).not_to have_selector('input#request_corporate_list_1_organization_name_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_organization_name_1"]', text: '会社名1 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_1_contents_1_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_1_title"]', text: '種別名 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_1_contents_1_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).not_to have_selector('.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config')
  expect(page).not_to have_selector('.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config button.add_corporate_list_url_contents_config', text: '追加')
  expect(page).not_to have_selector('.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config button.remove_corporate_list_url_contents_config', text: '削除')

  find('#corporate_list_1_details_toggle_btn', text: '詳細設定を開く').click # Open

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    find('button.add_corporate_list_url_contents_config', text: '追加').click
  end

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_1_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_2_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_1_contents_2_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_2_text_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_2_text_2"]', text: 'サンプル文字2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_2_text_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_2_text_3"]', text: 'サンプル文字3 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_1_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_1_contents_3_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_3_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    find('button.add_corporate_list_url_contents_config', text: '追加').click
  end

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_1_contents_3_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_3_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_1_contents_3_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_3_text_1"]', text: 'サンプル文字1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_3_text_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_3_text_2"]', text: 'サンプル文字2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_3_text_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_3_text_3"]', text: 'サンプル文字3 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_1_contents_4_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_4_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_1_contents_4_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_4_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    find('button.remove_corporate_list_url_contents_config', text: '削除').click
  end

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_1_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_2_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_1_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_1_contents_3_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_3_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    find('button.remove_corporate_list_url_contents_config', text: '削除').click
  end

  within '.field_corporate_list_config[url_num="1"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config.disabled', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_1_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_1_contents_1_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_1_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_1_contents_2_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_1_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')

  find('button#add_corporate_list_url_config', text: '追加').click

  expect(page).to have_selector('button#remove_corporate_list_url_config:not(.disabled)', text: '削除')

  expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる')
  within('.field_corporate_list_config[url_num="1"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_list_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_2_details_toggle_btn', text: '詳細設定を開く')
  expect(page).to have_selector('div', text: '詳細設定なし')
  within('.field_corporate_list_config[url_num="2"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).not_to have_selector('input#request_corporate_list_2_organization_name_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_organization_name_1"]', text: '会社名1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_3_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く')



  find('button#add_corporate_list_url_config', text: '追加').click

  expect(page).to have_selector('button#remove_corporate_list_url_config:not(.disabled)', text: '削除')

  expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる')
  within('.field_corporate_list_config[url_num="1"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_list_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_2_details_toggle_btn', text: '詳細設定を開く')
  within('.field_corporate_list_config[url_num="2"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_list_3_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く')
  expect(page).to have_selector('div', text: '詳細設定なし')
  within('.field_corporate_list_config[url_num="3"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).not_to have_selector('input#request_corporate_list_3_organization_name_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_organization_name_1"]', text: '会社名1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_4_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_4_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_list_4_details_toggle_btn', text: '詳細設定を開く')

  find('button#remove_corporate_list_url_config', text: '削除').click

  expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる')

  expect(page).to have_selector('input#request_corporate_list_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_2_details_toggle_btn', text: '詳細設定を開く')

  expect(page).not_to have_selector('input#request_corporate_list_3_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く')

  find('button#remove_corporate_list_url_config', text: '削除').click

  expect(page).to have_selector('button#remove_corporate_list_url_config.disabled', text: '削除')

  expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる')

  expect(page).not_to have_selector('input#request_corporate_list_2_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_list_2_details_toggle_btn', text: '詳細設定を開く')

  find('button#add_corporate_list_url_config', text: '追加').click
  find('button#add_corporate_list_url_config', text: '追加').click

  expect(page).to have_selector('input#request_corporate_list_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_1_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_1_details_toggle_btn', text: '詳細設定を閉じる')
  within('.field_corporate_list_config[url_num="1"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_list_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_2_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_2_details_toggle_btn', text: '詳細設定を開く')
  within('.field_corporate_list_config[url_num="2"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_list_3_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_url"]', text: '企業一覧ページのサンプルURL')
  expect(page).to have_selector('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く')
  within('.field_corporate_list_config[url_num="3"]')  { expect(page).to have_selector('div', text: '詳細設定なし') }


  find('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く').click # Open

  within('.field_corporate_list_config[url_num="3"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }
  expect(page).to have_selector('#corporate_list_3_details_toggle_btn', text: '詳細設定を閉じる')
  expect(page).to have_selector('input#request_corporate_list_3_organization_name_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_organization_name_1"]', text: '会社名1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_organization_name_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_organization_name_2"]', text: '会社名2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_organization_name_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_organization_name_3"]', text: '会社名3 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_organization_name_4[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_organization_name_4"]', text: '会社名4 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_3_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_1_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_3_contents_1_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_1_text_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_1_text_2"]', text: 'サンプル文字2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_1_text_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_1_text_3"]', text: 'サンプル文字3 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_3_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_2_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.add_corporate_list_url_contents_config', text: '追加')
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config.disabled', text: '削除')
  end

  # ２は開かない
  expect(page).not_to have_selector('input#request_corporate_list_2_organization_name_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_organization_name_1"]', text: '会社名1 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_2_contents_1_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_2_contents_1_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_2_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')

  find('#corporate_list_3_details_toggle_btn', text: '詳細設定を閉じる').click # Close

  within('.field_corporate_list_config[url_num="3"]') { expect(page).to have_selector('div', text: '詳細設定なし') }
  expect(page).to have_selector('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く')

  expect(page).not_to have_selector('input#request_corporate_list_3_organization_name_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_organization_name_1"]', text: '会社名1 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_1_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_1_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).not_to have_selector('.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config')
  expect(page).not_to have_selector('.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config button.add_corporate_list_url_contents_config', text: '追加')
  expect(page).not_to have_selector('.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config button.remove_corporate_list_url_contents_config.disabled', text: '削除')

  find('#corporate_list_3_details_toggle_btn', text: '詳細設定を開く').click # Open

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    find('button.add_corporate_list_url_contents_config', text: '追加').click
  end

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_3_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_3_contents_2_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_2_text_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_text_2"]', text: 'サンプル文字2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_2_text_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_text_3"]', text: 'サンプル文字3 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_3_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_3_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_3_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    find('button.add_corporate_list_url_contents_config', text: '追加').click
  end

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_3_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_2_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).to have_selector('input#request_corporate_list_3_contents_3_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_3_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_3_text_1"]', text: 'サンプル文字1 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_3_text_2[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_3_text_2"]', text: 'サンプル文字2 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_3_text_3[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_3_text_3"]', text: 'サンプル文字3 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_3_contents_4_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_4_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_4_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_4_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    find('button.remove_corporate_list_url_contents_config', text: '削除').click
  end

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_3_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_2_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_3_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_3_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_3_text_1"]', text: 'サンプル文字1 または そのXパス')

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    find('button.remove_corporate_list_url_contents_config', text: '削除').click
  end

  within '.field_corporate_list_config[url_num="3"] .corporate_list_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_list_url_contents_config.disabled', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_list_3_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_list_3_contents_1_text_1[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_list_3_contents_1_text_1"]', text: 'サンプル文字1 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_list_3_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_list_3_contents_2_text_1[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_list_3_contents_2_text_1"]', text: 'サンプル文字1 または そのXパス')
end



#--------------------------
#
#   企業個別ページの設定
#
#--------------------------
def confirm_corporate_individual_page_config_operation

  find("h3", text: 'より正確にクロールするための詳細設定').click # Open

  find("h5", text: '企業個別ページの設定').click # Open
  expect(page).not_to have_selector('#corporate_individual_config_off', text: '設定なし')
  expect(page).to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を開く')
  expect(page).to have_selector('div', text: '詳細設定なし')

  expect(page).not_to have_selector('input#request_corporate_individual_1_organization_name[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_organization_name"]', text: '会社名 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_2_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_individual_2_details_toggle_btn', text: '詳細設定を開く')

  expect(page).to have_selector('#add_corporate_individual_url_config', text: '追加')
  expect(page).to have_selector('#remove_corporate_individual_url_config.disabled', text: '削除')

  find("h5", text: '企業個別ページの設定').click # Close

  expect(page).to have_selector('#corporate_individual_config_off', text: '設定なし')
  expect(page).not_to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を開く')
  expect(page).not_to have_selector('div', text: '詳細設定なし')

  expect(page).not_to have_selector('#add_corporate_individual_url_config', text: '追加')
  expect(page).not_to have_selector('#remove_corporate_individual_url_config', text: '削除')

  find("h5", text: '企業個別ページの設定').click # Open
  find('#corporate_individual_1_details_toggle_btn', text: '詳細設定を開く').click # Open

  expect(page).not_to have_selector('div', text: '詳細設定なし')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる')
  expect(page).to have_selector('input#request_corporate_individual_1_organization_name[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_organization_name"]', text: '会社名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_1_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_1_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_1_contents_1_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_2_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.add_corporate_individual_url_contents_config', text: '追加')
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config.disabled', text: '削除')
  end

  find('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる').click # Close

  expect(page).to have_selector('div', text: '詳細設定なし')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を開く')
  expect(page).not_to have_selector('input#request_corporate_individual_1_organization_name[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_organization_name"]', text: '会社名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_1_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_1_title"]', text: '種別名 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_1_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config')
  expect(page).not_to have_selector('.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config button.add_corporate_individual_url_contents_config', text: '追加')
  expect(page).not_to have_selector('.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config button.remove_corporate_individual_url_contents_config', text: '削除')

  find('#corporate_individual_1_details_toggle_btn', text: '詳細設定を開く').click # Open

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    find('button.add_corporate_individual_url_contents_config', text: '追加').click
  end

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_1_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_2_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_1_contents_2_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_3_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_3_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    find('button.add_corporate_individual_url_contents_config', text: '追加').click
  end

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_1_contents_3_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_3_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_1_contents_3_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_3_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_4_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_4_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_4_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_4_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    find('button.remove_corporate_individual_url_contents_config', text: '削除').click
  end

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_1_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_individual_1_contents_2_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_3_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_3_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    find('button.remove_corporate_individual_url_contents_config', text: '削除').click
  end

  within '.field_corporate_individual_config[url_num="1"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config.disabled', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_1_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_individual_1_contents_1_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_1_contents_2_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_1_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  find('button#add_corporate_individual_url_config', text: '追加').click

  expect(page).to have_selector('button#remove_corporate_individual_url_config:not(.disabled)', text: '削除')

  expect(page).to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる')
  within('.field_corporate_individual_config[url_num="1"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_individual_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_2_details_toggle_btn', text: '詳細設定を開く')
  expect(page).to have_selector('div', text: '詳細設定なし')
  within('.field_corporate_individual_config[url_num="2"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).not_to have_selector('input#request_corporate_individual_2_organization_name[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_organization_name"]', text: '会社名 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_3_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_url"]', text: '企業個別ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く')



  find('button#add_corporate_individual_url_config', text: '追加').click

  expect(page).to have_selector('button#remove_corporate_individual_url_config:not(.disabled)', text: '削除')

  expect(page).to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる')
  within('.field_corporate_individual_config[url_num="1"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_individual_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_2_details_toggle_btn', text: '詳細設定を開く')
  within('.field_corporate_individual_config[url_num="2"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_individual_3_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く')
  expect(page).to have_selector('div', text: '詳細設定なし')
  within('.field_corporate_individual_config[url_num="3"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).not_to have_selector('input#request_corporate_individual_3_organization_name[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_organization_name"]', text: '会社名 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_4_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_4_url"]', text: '企業個別ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_individual_4_details_toggle_btn', text: '詳細設定を開く')

  find('button#remove_corporate_individual_url_config', text: '削除').click

  expect(page).to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる')

  expect(page).to have_selector('input#request_corporate_individual_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_2_details_toggle_btn', text: '詳細設定を開く')

  expect(page).not_to have_selector('input#request_corporate_individual_3_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_url"]', text: '企業個別ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く')

  find('button#remove_corporate_individual_url_config', text: '削除').click

  expect(page).to have_selector('button#remove_corporate_individual_url_config.disabled', text: '削除')

  expect(page).to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる')

  expect(page).not_to have_selector('input#request_corporate_individual_2_url[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).not_to have_selector('#corporate_individual_2_details_toggle_btn', text: '詳細設定を開く')

  find('button#add_corporate_individual_url_config', text: '追加').click
  find('button#add_corporate_individual_url_config', text: '追加').click

  expect(page).to have_selector('input#request_corporate_individual_1_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_1_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_1_details_toggle_btn', text: '詳細設定を閉じる')
  within('.field_corporate_individual_config[url_num="1"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_individual_2_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_2_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_2_details_toggle_btn', text: '詳細設定を開く')
  within('.field_corporate_individual_config[url_num="2"]') { expect(page).to have_selector('div', text: '詳細設定なし') }

  expect(page).to have_selector('input#request_corporate_individual_3_url[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_url"]', text: '企業個別ページのサンプルURL')
  expect(page).to have_selector('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く')
  within('.field_corporate_individual_config[url_num="3"]')  { expect(page).to have_selector('div', text: '詳細設定なし') }


  find('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く').click # Open

  within('.field_corporate_individual_config[url_num="3"]') { expect(page).not_to have_selector('div', text: '詳細設定なし') }
  expect(page).to have_selector('#corporate_individual_3_details_toggle_btn', text: '詳細設定を閉じる')
  expect(page).to have_selector('input#request_corporate_individual_3_organization_name[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_organization_name"]', text: '会社名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_3_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_1_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_3_contents_1_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_2_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.add_corporate_individual_url_contents_config', text: '追加')
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config.disabled', text: '削除')
  end

  # ２は開かない
  expect(page).not_to have_selector('input#request_corporate_individual_2_organization_name[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_organization_name"]', text: '会社名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_2_contents_1_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_2_contents_1_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_2_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  find('#corporate_individual_3_details_toggle_btn', text: '詳細設定を閉じる').click # Close

  within('.field_corporate_individual_config[url_num="3"]') { expect(page).to have_selector('div', text: '詳細設定なし') }
  expect(page).to have_selector('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く')

  expect(page).not_to have_selector('input#request_corporate_individual_3_organization_name[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_organization_name"]', text: '会社名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_1_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_1_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config')
  expect(page).not_to have_selector('.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config button.add_corporate_individual_url_contents_config', text: '追加')
  expect(page).not_to have_selector('.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config button.remove_corporate_individual_url_contents_config.disabled', text: '削除')

  find('#corporate_individual_3_details_toggle_btn', text: '詳細設定を開く').click # Open

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    find('button.add_corporate_individual_url_contents_config', text: '追加').click
  end

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_3_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_2_title"]', text: '種別名 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_3_contents_2_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_3_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_3_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    find('button.add_corporate_individual_url_contents_config', text: '追加').click
  end

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_3_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_individual_3_contents_2_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).to have_selector('input#request_corporate_individual_3_contents_3_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_individual_3_contents_3_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_3_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_4_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_4_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_4_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_4_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    find('button.remove_corporate_individual_url_contents_config', text: '削除').click
  end

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config:not(.disabled)', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_3_contents_2_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_individual_3_contents_2_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_2_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_3_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_3_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_3_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_3_text"]', text: 'サンプル文字 または そのXパス')

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    find('button.remove_corporate_individual_url_contents_config', text: '削除').click
  end

  within '.field_corporate_individual_config[url_num="3"] .corporate_individual_url_details_config' do
    expect(page).to have_selector('button.remove_corporate_individual_url_contents_config.disabled', text: '削除')
  end

  expect(page).to have_selector('input#request_corporate_individual_3_contents_1_title[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_1_title"]', text: '種別名 または そのXパス')
  expect(page).to have_selector('input#request_corporate_individual_3_contents_1_text[type="text"]')
  expect(page).to have_selector('label[for="request_corporate_individual_3_contents_1_text"]', text: 'サンプル文字 または そのXパス')

  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_2_title[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_2_title"]', text: '種別名 または そのXパス')
  expect(page).not_to have_selector('input#request_corporate_individual_3_contents_2_text[type="text"]')
  expect(page).not_to have_selector('label[for="request_corporate_individual_3_contents_2_text"]', text: 'サンプル文字 または そのXパス')
end