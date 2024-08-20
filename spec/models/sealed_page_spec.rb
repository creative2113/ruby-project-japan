require 'rails_helper'

RSpec.describe SealedPage, type: :model do
  before { SealedPage.delete_items(['example.com']) }

  domain = 'example.com'

  describe 'ドメインにはスラッシュを含まない' do
    it 'domainにスラッシュを含んでいなければ、保存できること' do
      expect { SealedPage.new('aaa.com') }.not_to raise_error
    end

    it 'domainにスラッシュを含む文字列は保存できないこと' do
      expect { SealedPage.new('aaa.com/') }.to raise_error(RuntimeError)
    end
  end

  it 'カウントアップでカウントがプラス1されること' do
    sp = SealedPage.create(count: 1)
    sp.count_up

    expect(sp.count).to eq 2
    expect(sp.last_access_date).to eq Time.zone.today

    sp = SealedPage.new(domain).get
    expect(sp.count).to eq 2
    expect(sp.last_access_date).to eq Time.zone.today
  end

  context 'sealed_because_can_not_get?' do
    it '封じられたページにアクセスがない場合、FALSEが返ること' do
      expect(SealedPage.new(domain).exist?).to be_falsey
      expect(SealedPage.new(domain).sealed_because_can_not_get?).to be_falsey
    end

    it '封じられたページにアクセスがあり、安全でないと判断されている時、FALSEが返ること' do
      SealedPage.create(:unsafe, { domain: domain })
      expect(SealedPage.new(domain).exist?).to be_truthy
      expect(SealedPage.new(domain).sealed_because_can_not_get?).to be_falsey
    end

    it '封じられたページにアクセスがあり、安全か不明と判断されている時、FALSEが返ること' do
      SealedPage.create(:unknown, { domain: domain })
      expect(SealedPage.new(domain).exist?).to be_truthy
      expect(SealedPage.new(domain).sealed_because_can_not_get?).to be_falsey
    end

    it '封じられたページにアクセスがあるが、カウントが満たない場合、FALSEが返ること' do
      SealedPage.create(:can_not_get, { domain: domain, count: EasySettings.access_limit_to_sealed_page })
      expect(SealedPage.new(domain).sealed_because_can_not_get?).to be_falsey
    end

    it '封じられたページにアクセスもあり、カウントも制限を超えている場合、TRUEが返ること' do
      SealedPage.create(:can_not_get, { domain: domain, count: EasySettings.access_limit_to_sealed_page + 1 })
      expect(SealedPage.new(domain).exist?).to be_truthy
      expect(SealedPage.new(domain).sealed_because_can_not_get?).to be_truthy
    end
  end

  context 'sealed_because_of_unsafe?' do
    it '封じられたページにアクセスがない場合、FALSEが返ること' do
      expect(SealedPage.new(domain).exist?).to be_falsey
      expect(SealedPage.new(domain).sealed_because_of_unsafe?).to be_falsey
    end

    it '封じられたページにアクセスがあり、安全でないと判断されている時、TRUEが返ること' do
      SealedPage.create(:unsafe, { domain: domain })
      expect(SealedPage.new(domain).exist?).to be_truthy
      expect(SealedPage.new(domain).sealed_because_of_unsafe?).to be_truthy
    end

    it '封じられたページにアクセスがあり、安全か不明と判断されている時、FALSEが返ること' do
      SealedPage.create(:unknown, { domain: domain })
      expect(SealedPage.new(domain).exist?).to be_truthy
      expect(SealedPage.new(domain).sealed_because_of_unsafe?).to be_falsey
    end

    it '封じられたページにアクセスがあるが、カウントが満たない場合、FALSEが返ること' do
      SealedPage.create(:can_not_get, { domain: domain, count: EasySettings.access_limit_to_sealed_page })
      expect(SealedPage.new(domain).sealed_because_of_unsafe?).to be_falsey
    end

    it '封じられたページにアクセスもあり、カウントも制限を超えている場合、FALSEが返ること' do
      SealedPage.create(:can_not_get, { domain: domain, count: EasySettings.access_limit_to_sealed_page + 1 })
      expect(SealedPage.new(domain).exist?).to be_truthy
      expect(SealedPage.new(domain).sealed_because_of_unsafe?).to be_falsey
    end
  end

  context 'safe?' do
    it 'データがない時は、TRUEが返ること' do
      expect(SealedPage.new(domain).safe?).to be_truthy
    end

    it '安全でなく、カウントが5以上だが、データが1年も経っていない時は、FALSEが返ること' do
      SealedPage.create(:unsafe, { domain: domain, count: 5, last_access_date: Time.zone.today - 300.days })
      expect(SealedPage.new(domain).safe?).to be_falsey
    end

    it '安全でなく、カウントが5以上で、データが1年以上経っている時は、TRUEが返ること' do
      SealedPage.create(:unsafe, { domain: domain, count: 5, last_access_date: Time.zone.today - 1.year - 1.day })
      expect(SealedPage.new(domain).safe?).to be_truthy
    end

    it '安全でなく、カウントが4で、データが1年も経っていない時は、FALSEが返ること' do
      SealedPage.create(:unsafe, { domain: domain, count: 4, last_access_date: Time.zone.today - 300.days })
      expect(SealedPage.new(domain).safe?).to be_truthy
    end

    it '安全でなく、カウントが4で、データが1年以上経っている時は、FALSEが返ること' do
      SealedPage.create(:unsafe, { domain: domain, count: 4, last_access_date: Time.zone.today - 1.year - 1.day })
      expect(SealedPage.new(domain).safe?).to be_truthy
    end

    it '安全か不明な時、TRUEが返ること' do
      SealedPage.create(:unknown, { domain: domain })
      expect(SealedPage.new(domain).safe?).to be_truthy
    end
  end

  context 'クラスメソッド check_safety' do
    it 'SealedPageに5回以上登録されている場合は、:unsafe_from_saved_sealed_pageが返ること' do
      SealedPage.create(:unsafe, { domain: domain, count: 5, last_access_date: Time.zone.today - 300.day })
      expect(SealedPage.check_safety('http://' + domain + '/')).to eq :unsafe_from_saved_sealed_page
    end

    context 'SealedPageに登録されていなく、安全と判定された場合' do
      it ':probably_safeが返ること' do
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:safe)
        expect(SealedPage.check_safety('http://' + domain + '/')).to eq :probably_safe
      end

      it 'SealedPageに登録されないこと' do
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:safe)
        SealedPage.check_safety('http://' + domain + '/')
        expect(SealedPage.new(domain).exist?).to be_falsey
      end
    end

    context 'SealedPageに登録されており、安全と判定された場合' do
      it ':probably_safeが返ること' do
        SealedPage.create(:unsafe, { domain: domain, count: 4, last_access_date: Time.zone.today - 300.day })
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:safe)
        expect(SealedPage.check_safety('http://' + domain + '/')).to eq :probably_safe
      end

      it 'SealedPageから削除されること' do
        SealedPage.create(:unsafe, { domain: domain, count: 4, last_access_date: Time.zone.today - 300.day })
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:safe)
        SealedPage.check_safety('http://' + domain + '/')
        expect(SealedPage.new(domain).exist?).to be_falsey
      end
    end

    context 'SealedPageに登録されていなく、危険と判定された場合' do
      it ':unsafe_from_url_web_checkerが返ること' do
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:unsafe)
        expect(SealedPage.check_safety('http://' + domain + '/')).to eq :unsafe_from_url_web_checker
      end

      it 'SealedPageに登録されること' do
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:unsafe)
        SealedPage.check_safety('http://' + domain + '/')
        sealed_page = SealedPage.new(domain)
        expect(sealed_page.exist?).to be_truthy
        expect(sealed_page.count).to eq 1
        expect(sealed_page.last_access_date).to eq Time.zone.today
        expect(sealed_page.domain_type).to eq EasySettings.domain_type['entrance']
      end
    end

    context 'SealedPageに4回登録されていて、危険と判定された場合' do
      it ':unsafe_from_url_web_checkerが返ること' do
        SealedPage.create(:unsafe, { domain: domain, count: 4, last_access_date: Time.zone.today - 300.day })
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:unsafe)
        expect(SealedPage.check_safety('http://' + domain + '/')).to eq :unsafe_from_url_web_checker
      end

      it 'SealedPageが更新されること' do
        SealedPage.create(:unsafe, { domain: domain, count: 4, last_access_date: Time.zone.today - 300.day })
        allow_any_instance_of(Crawler::UrlSafeChecker).to receive(:get_rating).and_return(:unsafe)
        SealedPage.check_safety('http://' + domain + '/')
        sealed_page = SealedPage.new(domain)
        expect(sealed_page.exist?).to be_truthy
        expect(sealed_page.count).to eq 5
        expect(sealed_page.last_access_date).to eq Time.zone.today
        expect(sealed_page.domain_type).to eq EasySettings.domain_type['entrance']
      end
    end
  end
end
