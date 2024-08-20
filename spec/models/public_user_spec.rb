# require 'rails_helper'

# RSpec.describe PublicUser, type: :model do
#   ip    = '127.0.0.1'
#   today = Time.zone.today

#   # it 'アクセス制限に引っかかること' do
#   #   user = create(:public_user_exceed_access)
#   #   expect(user.over_access?).to be_truthy
#   # end

#   it 'アクセス制限に引っかからないこと、またレコードが更新されないこと' do
#     user  = create(:public_user, ip: '0.0.0.1', search_count: EasySettings.access_limit[:public])
#     user2 = create(:public_user_exceed_access_yesterday, ip: '0.0.0.2')
#     expect(user.over_access?).to be_falsey
#     expect(user2.over_access?).to be_falsey
#     expect(user.search_count).to eq EasySettings.access_limit[:public]
#     expect(user2.latest_access_date).to eq today - 1.day
#   end

#   it 'レコードがnilでも、アクセス制限に引っかからないこと、また、レコードが更新されること' do
#     user = create(:public_user, search_count: nil, last_search_count: nil, latest_access_date: nil)
#     expect(user.over_access?).to be_falsey
#     expect(user.search_count).to eq 0
#     expect(user.last_search_count).to eq nil
#     expect(user.latest_access_date).to eq today
#   end

#   it 'カウントアップで昨日のアクセスカウントが新しくカウントが1になること' do
#     user = create(:public_user_yesterday, search_count: 8, last_search_count: 5)
#     user.count_up
#     expect(user.search_count).to eq 1
#     expect(user.last_search_count).to eq 8
#     expect(user.latest_access_date).to eq today
#   end

#   it 'レコードがnilでもカウントアップで新しくカウントが1になること' do
#     user = create(:public_user, search_count: nil, last_search_count: nil, latest_access_date: nil)
#     user.count_up
#     expect(user.search_count).to eq 1
#     expect(user.last_search_count).to eq 0
#     expect(user.latest_access_date).to eq today
#   end

#   it 'カウントアップでカウントがプラス1されること' do
#     user = create(:public_user, search_count: 8, last_search_count: 5)
#     user.count_up
#     expect(user.search_count).to eq 9
#     expect(user.last_search_count).to eq 5
#     expect(user.latest_access_date).to eq today
#   end

#   it '今までアクセスがあったことを確認できること' do
#     user = create(:public_user, ip: ip, latest_access_date: today - 10)
#     expect(PublicUser.accessed?(ip)).to be_truthy
#   end

#   it '今までアクセスがなかったことを確認できること' do
#     ip2 = '127.0.0.2'
#     user  = create(:public_user, ip: ip, latest_access_date: today - 10)
#     expect(PublicUser.accessed?(ip2)).to be_falsey
#   end

#   it '現在のアクセスカウントアップで現在のアクセスカウントがプラス1されること' do
#     user = create(:public_user, current_access_count: 1)
#     user.count_up_current_access_count
#     expect(user.current_access_count).to eq 2
#   end

#   it 'もしレコードがnilまたはマイナスでも、現在のアクセスカウントアップで現在のアクセスカウントがプラス1されること' do
#     user  = create(:public_user, ip: '0.0.0.1', current_access_count: nil)
#     user2 = create(:public_user, ip: '0.0.0.2', current_access_count: -1)
#     user.count_up_current_access_count
#     user2.count_up_current_access_count
#     expect(user.current_access_count).to  eq 1
#     expect(user2.current_access_count).to eq 1
#   end

#   it '現在のアクセスカウントダウンで現在のアクセスカウントがマイナス1されること' do
#     user = create(:public_user, current_access_count: 2)
#     user.count_down_current_access_count
#     expect(user.current_access_count).to eq 1
#   end

#   it 'もし現在のアクセスカウントダウンで現在のアクセスカウントがマイナスになった場合、0に戻す' do
#     user = create(:public_user, current_access_count: 0)
#     user.count_down_current_access_count
#     expect(user.current_access_count).to eq 0
#   end

#   it 'もしレコードがnilまたはマイナスでも、現在のアクセスカウントアップで現在のアクセスカウントがマイナス1されること' do
#     user  = create(:public_user, ip: '0.0.0.1', current_access_count: nil)
#     user2 = create(:public_user, ip: '0.0.0.2', current_access_count: -1)
#     user.count_down_current_access_count
#     user2.count_down_current_access_count
#     expect(user.current_access_count).to  eq 0
#     expect(user2.current_access_count).to eq 0
#   end

#   it '現在のアクセスカウントでアクセス制限に引っかかること' do
#     user = create(:public_user, current_access_count: EasySettings.access_current_limit[:public] + 1)
#     expect(user.access_current_limit?).to be_truthy
#   end

#   it '現在のアクセスカウントでアクセス制限に引っかからないこと' do
#     user = create(:public_user, current_access_count: EasySettings.access_current_limit[:public])
#     expect(user.access_current_limit?).to be_falsey
#   end

#   it '現在のアクセスカウントがnilもしくはマイナスでも、アクセス制限に引っかからないこと' do
#     user  = create(:public_user, ip: '0.0.0.1', current_access_count: nil)
#     user2 = create(:public_user, ip: '0.0.0.2', current_access_count: -1)
#     expect(user.access_current_limit?).to be_falsey
#     expect(user2.access_current_limit?).to be_falsey
#     expect(user.current_access_count).to  eq 0
#     expect(user2.current_access_count).to eq 0
#   end

#   # it '複数リクエストでアクセス制限に引っかかること' do
#   #   user = create(:public_user_exceed_access)
#   #   expect(user.request_limit?).to be_truthy
#   # end

#   it '複数リクエストでアクセス制限に引っかからないこと' do
#     user  = build(:public_user, ip: '0.0.0.1', request_count: EasySettings.request_limit[:public])
#     user2 = build(:public_user_exceed_access_yesterday, ip: '0.0.0.2')
#     expect(user.request_limit?).to be_falsey
#     expect(user2.request_limit?).to be_falsey
#   end

#   it 'もしレコードがnilでも、複数リクエストでアクセス制限に引っかからないこと' do
#     user  = create(:public_user, ip: '0.0.0.1', request_count: nil, last_request_date: nil)
#     user2 = create(:public_user, ip: '0.0.0.2', request_count: -1,  last_request_date: nil)
#     expect(user.request_limit?).to  be_falsey
#     expect(user2.request_limit?).to be_falsey
#     expect(user.request_count).to      eq 0
#     expect(user.last_request_date).to  eq today
#     expect(user2.request_count).to     eq 0
#     expect(user2.last_request_date).to eq today
#   end

#   it '複数リクエストでカウントアップで昨日のアクセスカウントが新しくカウントが1になること' do
#     user = create(:public_user_exceed_access_yesterday, request_count: 8, last_request_count: 5)
#     user.request_count_up
#     expect(user.request_count).to eq 1
#     expect(user.last_request_count).to eq 8
#     expect(user.last_request_date).to eq today
#   end

#   it '複数リクエストでカウントアップでカウントがプラス1されること' do
#     user = create(:public_user, request_count: 3, last_request_count: 6)
#     user.request_count_up
#     expect(user.request_count).to eq 4
#     expect(user.last_request_count).to eq 6
#     expect(user.last_request_date).to eq today
#   end

#   it 'もしレコードがnilでも、複数リクエストでカウントアップでカウントがプラス1されること' do
#     user = create(:public_user, request_count: nil, last_request_count: nil , last_request_date: nil)
#     user.request_count_up
#     expect(user.request_count).to eq 1
#     expect(user.last_request_count).to eq 0
#     expect(user.last_request_date).to eq today
#   end
# end
