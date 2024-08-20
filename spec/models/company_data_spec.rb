require 'rails_helper'

RSpec.describe CompanyData, type: :model do
  before_data = [
    {name: " 商 \n\r号 \t\r", value: "株式会社 \nAAA ", priority: 1, group: 1},
    {name: "title", value: "株式会社AAAのサイト", priority: 1, group: 1},
    {name: "電\t話", value: '  000   -0000-1111  ', priority: 1, group: 1},
    {name: "主 要株 主", value: '(株)  BBBB', priority: 1, group: 1},
    {name: "売り上げ 高 ", value: "1 00\n億", priority: 1, group: 1},
    {name: "代  表 ", value: ' 田中 太郎', priority: 1, group: 1},
    {name: "社名", value: '株式会社 AAA', priority: 1, group: 1},
    {name: "役員 ", value: ' 田中 二郎', priority: 1, group: 1},
    {name: "事業 ", value: '販売、仲介', priority: 1, group: 1},
    {name: "取 \n\r 引先", value: 'CCC会社', priority: 1, group: 1},
    {name: "名古屋支店", value: '住所 愛知県名古屋市千種区5-4-4 03-5555-1111', priority: 1, group: 1},
    {name: "代 表電話", value: '  00-0000-3333  ', priority: 1, group: 1},
    {name: "資\v本 ", value: ' 2 00 億', priority: 1, group: 1},
    {name: "主要 事業 ", value: "製造\r", priority: 1, group: 1},
    {name: "AAA", value: ' 東京都港区虎ノ門8', priority: 1, group: 1},
    {name: "従業\v員数", value: "100人\nグループ全体 300人", priority: 1, group: 1},
    {name: "メインバンク", value: 'DDD銀行 ', priority: 1, group: 1},
    {name: "本\t社\r", value: ' 東京都八王子市南56-7', priority: 1, group: 1},
    {name: "カスタマーサポート電話", value: 'RRRR', priority: 1, group: 1}
  ]

  after_data = [
    {:name=>"url", :value=>"http://www.example.com", :category=>"url", :priority=>1000},
    {:name=>"domain", :value=>"www.example.com", :category=>"domain", :priority=>1000},
    {:name=>"商 号", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
    {:name=>"社名", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
    {:name=>"title", :value=>"株式会社AAAのサイト", :category=>"title", :priority=>1000},
    {:name=>"名古屋支店", :value=>"愛知県名古屋市千種区5-4-4", :category=>"extracted address"},
    {:name=>"名古屋支店", :value=>"03-5555-1111", :category=>"extracted telephone number"},
    {:name=>"資 本", :value=>"20,000,000,000", :category=>"extracted capital"},
    {:name=>"売り上げ 高", :value=>"10,000,000,000", :category=>"extracted sales amount"},
    {:name=>"従業 員数", :value=>"100", :category=>"extracted employee"},
    {:name=>"", :value=>"田中 太郎", :category=>"extracted representative"},
    {:name=>"電 話", :value=>"000 -0000-1111", :category=>"contact information", :priority=>1},
    {:name=>"名古屋支店", :value=>"住所 愛知県名古屋市千種区5-4-4 03-5555-1111", :category=>"contact information", :priority=>1},
    {:name=>"代 表電話", :value=>"00-0000-3333", :category=>"contact information", :priority=>1},
    {:name=>"AAA", :value=>"東京都港区虎ノ門8", :category=>"contact information", :priority=>1},
    {:name=>"本 社", :value=>"東京都八王子市南56-7", :category=>"contact information", :priority=>1},
    {:name=>"カスタマーサポート電話", :value=>"RRRR", :category=>"contact information", :priority=>1},
    {:name=>"代 表", :value=>"田中 太郎", :category=>"board member", :priority=>1},
    {:name=>"役員", :value=>"田中 二郎", :category=>"board member", :priority=>1},
    {:name=>"資 本", :value=>"2 00 億", :category=>"capital", :priority=>1},
    {:name=>"売り上げ 高", :value=>"1 00 億", :category=>"sales amount", :priority=>1},
    {:name=>"従業 員数", :value=>"100人 グループ全体 300人", :category=>"employee", :priority=>1},
    {:name=>"主 要株 主", :value=>"(株) BBBB", :category=>"stockholder", :priority=>1},
    {:name=>"事業", :value=>"販売、仲介", :category=>"business description", :priority=>1},
    {:name=>"主要 事業", :value=>"製造", :category=>"business description", :priority=>1},
    {:name=>"取 引先", :value=>"CCC会社", :category=>"others", :priority=>1},
    {:name=>"メインバンク", :value=>"DDD銀行", :category=>"others", :priority=>1}
  ]

  arrange_data = {
    "URL"=>"http://www.example.com",
    "ドメイン"=>"www.example.com",
    "名称"=>"株式会社 AAA",
    "サイトタイトル"=>"株式会社AAAのサイト",
    "抽出住所"=>"愛知県名古屋市千種区5-4-4",
    "抽出電話番号"=>"03-5555-1111",
    "抽出資本金"=>"20,000,000,000",
    "抽出売上"=>"10,000,000,000",
    "抽出従業員数"=>"100",
    "抽出代表名"=>"田中 太郎",
    "連絡先"=>
     {"電 話"=>"000 -0000-1111",
      "名古屋支店"=>"住所 愛知県名古屋市千種区5-4-4 03-5555-1111",
      "代 表電話"=>"00-0000-3333",
      "AAA"=>"東京都港区虎ノ門8",
      "本 社"=>"東京都八王子市南56-7",
      "カスタマーサポート電話"=>"RRRR"},
    "役員"=>{"代 表"=>"田中 太郎", "役員"=>"田中 二郎"},
    "資本金"=>"2 00 億",
    "売上"=>"1 00 億",
    "従業員数"=>"100人 グループ全体 300人",
    "株主"=>"(株) BBBB",
    "事業"=>{"事業"=>"販売、仲介", "主要 事業"=>"製造"},
    "その他"=>{"取 引先"=>"CCC会社", "メインバンク"=>"DDD銀行"}
  }

  arrange_data_for_excel = {
    "URL"=>"http://www.example.com",
    "ドメイン"=>"www.example.com",
    "名称"=>"株式会社 AAA",
    "サイトタイトル"=>"株式会社AAAのサイト",
    "抽出住所"=>"愛知県名古屋市千種区5-4-4",
    "抽出電話番号"=>"03-5555-1111",
    "抽出資本金"=>"20,000,000,000",
    "抽出売上"=>"10,000,000,000",
    "抽出従業員数"=>"100",
    "抽出代表名"=>"田中 太郎",
    "連絡先1"=>"電 話:000 -0000-1111",
    "連絡先2"=>"名古屋支店:住所 愛知県名古屋市千種区5-4-4 03-5555-1111",
    "連絡先3"=>"代 表電話:00-0000-3333",
    "連絡先4"=>"AAA:東京都港区虎ノ門8",
    "連絡先5"=>"本 社:東京都八王子市南56-7",
    "連絡先6"=>"カスタマーサポート電話:RRRR",
    "役員"=>{"代 表"=>"田中 太郎", "役員"=>"田中 二郎"},
    "資本金"=>"2 00 億",
    "売上"=>"1 00 億",
    "従業員数"=>"100人 グループ全体 300人",
    "株主"=>"(株) BBBB",
    "事業"=>{"事業"=>"販売、仲介", "主要 事業"=>"製造"},
    "その他1"=>"取 引先:CCC会社",
    "その他2"=>"メインバンク:DDD銀行"
  }

  category_counts = { Crawler::Items.address             => 2,
                      Crawler::Items.telephone           => 3,
                      Crawler::Items.contact_information => 0,
                      Crawler::Items.others              => 2 }

  describe do
    let(:data) { before_data }
    let(:cd) { CompanyData.new('http://www.example.com', data) }

    it '会社名を抽出できること' do
      expect(cd.name).to eq '株式会社 AAA'
    end

    it '会社データを綺麗にできること' do
      expect(cd.clean_data).to eq after_data
    end

    it '会社データを整理できること' do
      expect(cd.arrange).to eq arrange_data
    end

    it 'エクセル用に会社データを整理できること' do
      expect(cd.arrange_for_excel(category_counts)).to eq arrange_data_for_excel
    end

    it '既に整理されているデータは綺麗にならないこと' do
      expect(CompanyData.new('http://www.example.com', after_data).clean_data).to eq after_data
    end

    context do
      before_data2 = [
        {name: " 商 \n\r号 \t\r", value: "株式会社 \nAAA ", priority: 1, group: 1},
        {name: "title", value: "株式会社AAAのサイト", priority: 1, group: 1},
        {name: "TEL", value: '  000-0000-1111  ', priority: 1, group: 1},
        {name: "FAX", value: '  000-0000-2222  ', priority: 1, group: 1},
        {name: "本社", value: '住所　〒100-1000愛知県名古屋市千種区5-4-4', priority: 1, group: 1}
      ]

      after_data2 = [
        {:name=>"url", :value=>"http://www.example.com", :category=>"url", :priority=>1000},
        {:name=>"domain", :value=>"www.example.com", :category=>"domain", :priority=>1000},
        {:name=>"商 号", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
        {:name=>"title", :value=>"株式会社AAAのサイト", :category=>"title", :priority=>1000},
        {:name=>"本社", :value=>"100-1000", :category=>"extracted post code"},
        {:name=>"本社", :value=>"愛知県名古屋市千種区5-4-4", :category=>"extracted address"},
        {:name=>"TEL", :value=>"000-0000-1111", :category=>"extracted telephone number"},
        {:name=>"FAX", :value=>"000-0000-2222", :category=>"extracted fax"},
        {:name=>"TEL", :value=>"000-0000-1111", :category=>"contact information", :priority=>1},
        {:name=>"FAX", :value=>"000-0000-2222", :category=>"contact information", :priority=>1},
        {:name=>"本社", :value=>"住所 〒100-1000愛知県名古屋市千種区5-4-4", :category=>"contact information", :priority=>1}
      ]
      let(:data) { before_data2 }
      it '会社データを綺麗にできること' do
        expect(cd.clean_data).to eq after_data2
      end
    end

    context do
      before_data3 = [
        {name: "商号", value: "株式会社 AAA ", priority: 1, group: 1},
        {name: "title", value: "株式会社AAAのサイト", priority: 1, group: 1},
        {name: "電話番号", value: 'TEL. 000-0000-1111 FAX. 000-0000-2222', priority: 1, group: 1},
        {name: "本社", value: '住所　愛知県名古屋市千種区5-4-4 TEL. 000-0000-3333 FAX. 000-0000-4444', priority: 1, group: 1}
      ]

      after_data3 = [
        {:name=>"url", :value=>"http://www.example.com", :category=>"url", :priority=>1000},
        {:name=>"domain", :value=>"www.example.com", :category=>"domain", :priority=>1000},
        {:name=>"商号", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
        {:name=>"title", :value=>"株式会社AAAのサイト", :category=>"title", :priority=>1000},
        {:name=>"本社", :value=>"愛知県名古屋市千種区5-4-4", :category=>"extracted address"},
        {:name=>"電話番号", :value=>"000-0000-1111", :category=>"extracted telephone number"},
        {:name=>"電話番号", :value=>"000-0000-2222", :category=>"extracted fax"},
        {:name=>"電話番号", :value=>"TEL. 000-0000-1111 FAX. 000-0000-2222", :category=>"contact information", :priority=>1},
        {:name=>"本社", :value=>"住所 愛知県名古屋市千種区5-4-4 TEL. 000-0000-3333 FAX. 000-0000-4444", :category=>"contact information", :priority=>1}
      ]
      let(:data) { before_data3 }
      it '会社データを綺麗にできること' do
        expect(cd.clean_data).to eq after_data3
      end
    end

    context do
      before_data4 = [
        {name: "商号", value: "株式会社 AAA ", priority: 1},
        {name: "title", value: "株式会社AAAのサイト", priority: 1},
        {name: "本社", value: '住所　〒100-1000愛知県名古屋市千種区5-4-4 TEL. 000-0000-3333 FAX. 000-0000-4444', priority: 1}
      ]

      after_data4 = [
        {:name=>"url", :value=>"http://www.example.com", :category=>"url", :priority=>1000},
        {:name=>"domain", :value=>"www.example.com", :category=>"domain", :priority=>1000},
        {:name=>"商号", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
        {:name=>"title", :value=>"株式会社AAAのサイト", :category=>"title", :priority=>1000},
        {:name=>"本社", :value=>"100-1000", :category=>"extracted post code"},
        {:name=>"本社", :value=>"愛知県名古屋市千種区5-4-4", :category=>"extracted address"},
        {:name=>"本社", :value=>"000-0000-3333", :category=>"extracted telephone number"},
        {:name=>"本社", :value=>"000-0000-4444", :category=>"extracted fax"},
        {:name=>"本社", :value=>"住所 〒100-1000愛知県名古屋市千種区5-4-4 TEL. 000-0000-3333 FAX. 000-0000-4444", :category=>"contact information", :priority=>1}
      ]
      let(:data) { before_data4 }
      it '会社データを綺麗にできること' do
        expect(cd.clean_data).to eq after_data4
      end
    end

    context do
      before_data5 = [
        {name: "商号", value: "株式会社 AAA ", priority: 1},
        {name: "title", value: "株式会社AAAのサイト", priority: 1},
        {name: "本社", value: 'TEL:000-0000-3333 FAX:000-0000-4444/000-0000-5555 〒100-1000愛知県名古屋市千種区5-4-4 〒100-2000東京都八王子市石川町54-4', priority: 1}
      ]

      after_data5 = [
        {:name=>"url", :value=>"http://www.example.com", :category=>"url", :priority=>1000},
        {:name=>"domain", :value=>"www.example.com", :category=>"domain", :priority=>1000},
        {:name=>"商号", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
        {:name=>"title", :value=>"株式会社AAAのサイト", :category=>"title", :priority=>1000},
        {:name=>"本社", :value=>"100-1000", :category=>"extracted post code"},
        {:name=>"本社", :value=>"愛知県名古屋市千種区5-4-4", :category=>"extracted address"},
        {:name=>"本社", :value=>"000-0000-3333", :category=>"extracted telephone number"},
        {:name=>"本社", :value=>"000-0000-4444", :category=>"extracted fax"},
        {:name=>"本社",
         :value=>"TEL:000-0000-3333 FAX:000-0000-4444/000-0000-5555 〒100-1000愛知県名古屋市千種区5-4-4 〒100-2000東京都八王子市石川町54-4",
         :category=>"contact information",
         :priority=>1}
      ]
      let(:data) { before_data5 }
      it '会社データを綺麗にできること' do
        expect(cd.clean_data).to eq after_data5
      end
    end

    context do
      before_data6 = [
        {name: "商号", value: "株式会社 AAA ", priority: 1},
        {name: "title", value: "株式会社AAAのサイト", priority: 1},
        {name: "本社", value: '000-0000-3333(TEL) 000-0000-4444/000-0000-5555(FAX) 〒100-1000愛知県名古屋市千種区5-4-4 〒100-2000東京都八王子市石川町54-4', priority: 1}
      ]

      after_data6 = [
        {:name=>"url", :value=>"http://www.example.com", :category=>"url", :priority=>1000},
        {:name=>"domain", :value=>"www.example.com", :category=>"domain", :priority=>1000},
        {:name=>"商号", :value=>"株式会社 AAA", :category=>"company name", :priority=>1},
        {:name=>"title", :value=>"株式会社AAAのサイト", :category=>"title", :priority=>1000},
        {:name=>"本社", :value=>"100-1000", :category=>"extracted post code"},
        {:name=>"本社", :value=>"愛知県名古屋市千種区5-4-4", :category=>"extracted address"},
        {:name=>"本社", :value=>"000-0000-3333", :category=>"extracted telephone number"},
        {:name=>"本社", :value=>"000-0000-4444", :category=>"extracted fax"},
        {:name=>"本社",
         :value=>"000-0000-3333(TEL) 000-0000-4444/000-0000-5555(FAX) 〒100-1000愛知県名古屋市千種区5-4-4 〒100-2000東京都八王子市石川町54-4",
         :category=>"contact information",
         :priority=>1}]
      let(:data) { before_data6 }
      it '会社データを綺麗にできること' do
        expect(cd.clean_data).to eq after_data6
      end
    end
  end
end