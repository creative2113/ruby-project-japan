require 'rails_helper'
require 'corporate_results'

RSpec.describe AccessRecord, type: :model do
  before { AccessRecord.delete_items(['example.com', 'aaa.com']) }

  let(:domain)          { 'example.com' }
  let(:count)           { 1 }
  let(:name)            { RES_HOKKAIDO_COCA_COLA[2][:value].to_s }
  let(:result)          { RES_HOKKAIDO_COCA_COLA }
  let(:urls)            { HOKKAIDO_COCA_COLA_TARGET_URLS }
  let(:accessed_urls)   { HOKKAIDO_COCA_COLA_ACCESSED_URLS }
  let(:supporting_urls) { nil }
  let!(:ar)              { AccessRecord.create(domain: domain, count: count, name: name, result: result,
                                               urls: urls, accessed_urls: accessed_urls,
                                               supporting_urls: supporting_urls) }

  describe 'ドメインにはスラッシュを含まない' do
    it 'domainにスラッシュを含んでいなければ、保存できること' do
      expect { AccessRecord.new('aaa.com') }.not_to raise_error
    end

    it 'domainにスラッシュを含む文字列は保存できないこと' do
      expect { AccessRecord.new('aaa.com/') }.to raise_error(RuntimeError)
    end
  end

  describe 'count_up' do
    let(:ar) { AccessRecord.create(:yesterday) }

    it 'カウントアップでカウントが1増えること' do
      Timecop.freeze(current_time)

      ar.count_up
      expect(ar.count).to eq 2
      expect(ar.last_access_date).to eq current_time

      ar = AccessRecord.new(domain).get
      expect(ar.count).to eq 2
      expect(ar.last_access_date).to eq current_time
      Timecop.return
    end
  end

  describe 'result' do
    it 'resultの値がハッシュで返ること' do
      expect(ar.result).to eq RES_HOKKAIDO_COCA_COLA
    end
  end

  describe 'urls' do
    it 'urlsの値がハッシュで返ること' do
      expect(ar.get.urls).to eq HOKKAIDO_COCA_COLA_TARGET_URLS
    end
  end

  describe 'urls' do
    it 'accessed_urlsの値がハッシュで返ること' do
      expect(ar.accessed_urls).to eq HOKKAIDO_COCA_COLA_ACCESSED_URLS
    end
  end

  describe 'accessed?' do
    context '過去にアクセスがあった場合' do
      it 'アクセスがあったことを確認できること' do
        expect(ar.accessed?).to be_truthy
      end
    end

    context '過去にアクセスがあった場合' do
      let(:count) { 0 }
      it 'アクセスがなかったことを確認できること' do
        expect(ar.accessed?).to be_falsey
      end
    end
  end

  describe 'supporting_urls' do
    context 'supporting_urlsがない場合' do
      it '空の配列[]が返ること' do
        expect(ar.supporting_urls).to eq([])
      end
    end

    context 'supporting_urlsがある場合' do
      let(:supporting_urls) { HOKKAIDO_COCA_COLA_ACCESSED_URLS }
      it 'supporting_urlsの値が配列で返ること' do
        expect(ar.supporting_urls).to eq HOKKAIDO_COCA_COLA_ACCESSED_URLS
      end
    end
  end

  describe 'exist?' do
    it '特定のドメインのレコードがあること、ないことを確認できること' do
      expect(AccessRecord.new(domain).exist?).to be_truthy
      expect(AccessRecord.new('www.example2.jp').exist?).to be_falsey
    end
  end

  describe 'update' do
    it '正しくupdateされること' do
      Timecop.freeze(current_time)

      domain = 'example.com'
      AccessRecord.create(:normal)

      AccessRecord.new(domain, {count: 8, last_fetch_date: Time.zone.today - 8.days}).update

      ar = AccessRecord.new(domain).get
      expect(ar.exist?).to be_truthy
      expect(ar.domain).to eq domain
      expect(ar.count).to eq 8
      expect(ar.last_access_date).to eq Time.zone.now
      expect(ar.last_fetch_date).to eq (Time.zone.today - 8.days).to_time

      AccessRecord.new(domain).update(:all, {count: 100,
                                             last_access_date: Time.zone.now - 5.days,
                                             last_fetch_date: Time.zone.today - 12.days})

      ar = AccessRecord.new(domain).get
      expect(ar.exist?).to be_truthy
      expect(ar.domain).to eq domain
      expect(ar.count).to eq 100
      expect(ar.last_access_date).to eq Time.zone.now - 5.days
      expect(ar.last_fetch_date).to eq (Time.zone.today - 12.days).to_time
    end


  end

  describe 'クラスメソッド create' do
    it '正しくデータが作られること' do
      Timecop.freeze(current_time)
      AccessRecord.create(:normal)

      ar = AccessRecord.new(domain).get
      expect(ar.exist?).to be_truthy
      expect(ar.domain).to eq 'example.com'
      expect(ar.count).to eq 1
      expect(ar.last_access_date).to eq Time.zone.now
      expect(ar.last_fetch_date).to eq Time.zone.now
      Timecop.return
    end

    it '正しくデータが作られること' do
      Timecop.freeze(current_time)
      domain = 'aaa.com'
      date   = Time.zone.today - 4.days
      AccessRecord.create(:normal, {domain: domain, last_fetch_date: date})

      ar = AccessRecord.new(domain).get
      expect(ar.exist?).to be_truthy
      expect(ar.domain).to eq domain
      expect(ar.count).to eq 1
      expect(ar.last_access_date).to eq Time.zone.now
      expect(ar.last_fetch_date).to eq date.to_time
      Timecop.return
    end

    it '正しくデータが作られること' do
      Timecop.freeze(current_time)
      domain = 'aaa.com'
      date   = Time.zone.today - 4.days
      AccessRecord.create(domain: domain, last_fetch_date: date)

      ar = AccessRecord.new(domain).get
      expect(ar.exist?).to be_truthy
      expect(ar.domain).to eq domain
      expect(ar.count).to eq 1
      expect(ar.last_access_date).to eq Time.zone.now
      expect(ar.last_fetch_date).to eq date.to_time
      Timecop.return
    end

    it '正しくデータが作られること' do
      Timecop.freeze(current_time)
      AccessRecord.create(:yesterday, {count: 5})

      ar = AccessRecord.new(domain).get
      expect(ar.exist?).to be_truthy
      expect(ar.domain).to eq 'example.com'
      expect(ar.count).to eq 5
      expect(ar.last_access_date).to eq Time.zone.now - 1.day
      expect(ar.last_fetch_date).to eq Time.zone.now
      Timecop.return
    end
  end
end
