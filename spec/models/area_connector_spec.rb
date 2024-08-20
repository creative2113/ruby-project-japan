require 'rails_helper'

RSpec.describe AreaConnector, type: :model do

  describe '#check_blank' do
    let(:region) { create(:region, name: '関東') }
    let(:prefecture) { create(:prefecture, name: '東京都') }
    let(:city) { create(:city, name: '新宿区') }

    it do
      expect { AreaConnector.create!(region: region, prefecture: nil, city: city) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { AreaConnector.create!(region: nil, prefecture: nil, city: city) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { AreaConnector.create!(region: nil, prefecture: prefecture, city: city) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { AreaConnector.create!(region: nil, prefecture: prefecture, city: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#find_or_create' do
    subject { described_class.find_or_create(region, prefecture, city) }
    let(:region) { create(:region, name: '関東') }
    let(:prefecture) { create(:prefecture, name: '東京都') }
    let(:city) { create(:city, name: '新宿区') }
    let(:connector) { create(:area_connector, region: region, prefecture: prefecture, city: city) }

    context '存在しているとき' do
      before do
        connector
      end

      it { expect{ subject }.to change(AreaConnector, :count).by(0) }
      it { expect(subject).to eq connector }
    end

    context '存在していないとき' do
      it { expect{ subject }.to change(AreaConnector, :count).by(1) }
      it { expect(subject).to eq AreaConnector.last }
    end
  end

  describe '#make_where_clause' do
    subject { described_class.make_where_clause(connector_ids) }
    let(:region) { create(:region, name: '関東') }
    let(:prefecture) { create(:prefecture, name: '東京都') }
    let(:city) { create(:city, name: '新宿区') }
    let(:connector1) { create(:area_connector, region: region, prefecture: nil, city: nil) }
    let(:connector2) { create(:area_connector, region: region, prefecture: prefecture, city: nil) }
    let(:connector3) { create(:area_connector, region: region, prefecture: prefecture, city: city) }

    context do
      let(:connector_ids) { [connector1.id] }
      before do
        connector1
      end
      it do
        expect(subject).to eq "( area_connectors.region_id = #{region.id}  ) "
      end
    end

    context do
      let(:connector_ids) { [connector1.id, connector2.id] }
      before do
        connector1
        connector2
      end
      it do
        expect(subject).to eq "( area_connectors.region_id = #{region.id}  ) OR ( area_connectors.region_id = #{region.id} AND area_connectors.prefecture_id = #{prefecture.id}  ) "
      end
    end

    context do
      let(:connector_ids) { [connector1.id, connector2.id, connector3.id] }
      before do
        connector1
        connector2
        connector3
      end
      it do
        expect(subject).to eq "( area_connectors.region_id = #{region.id}  ) OR ( area_connectors.region_id = #{region.id} AND area_connectors.prefecture_id = #{prefecture.id}  ) OR " +
                              "( area_connectors.region_id = #{region.id} AND area_connectors.prefecture_id = #{prefecture.id} AND area_connectors.city_id = #{city.id}  ) "
      end
    end
  end

  describe '#find_all_area_comb' do
    subject { described_class.find_all_area_comb }
    let(:region) { create(:region, name: '関東') }
    let(:region2) { create(:region, name: '近畿') }
    let(:prefecture) { create(:prefecture, name: '東京都') }
    let(:prefecture2) { create(:prefecture, name: '大阪府') }
    let(:city) { create(:city, name: '新宿区') }
    let(:city2) { create(:city, name: '大阪市') }
    let(:connector1) { create(:area_connector, region: region, prefecture: nil, city: nil) }
    let(:connector2) { create(:area_connector, region: region, prefecture: prefecture, city: nil) }
    let(:connector3) { create(:area_connector, region: region, prefecture: prefecture, city: city) }
    let(:connector4) { create(:area_connector, region: region, prefecture: prefecture, city: city2) }
    let(:connector5) { create(:area_connector, region: region, prefecture: prefecture2, city: nil) }
    let(:connector6) { create(:area_connector, region: region2, prefecture: nil, city: nil) }

    context '地方だけの時' do
      before do
        connector1
      end
      it do
        expect(subject).to eq [{region_id: region.id, name: region.name, connector_id: connector1.id, prefecture: []}]
      end
    end

    context '地方、都道府県だけの時' do
      before do
        connector1
        connector2
      end
      it do
        expect(subject).to eq [{region_id: region.id, name: region.name, connector_id: connector1.id, prefecture: [{prefecture_id: prefecture.id, name: prefecture.name, connector_id: connector2.id, city: []}]}]
      end
    end

    context '地方、都道府県、市区町村の時' do
      before do
        connector1
        connector2
        connector3
      end
      it do
        expect(subject).to eq [
                                {region_id: region.id, name: region.name, connector_id: connector1.id, prefecture: [
                                                                                                                     { prefecture_id: prefecture.id, name: prefecture.name, connector_id: connector2.id, city: [ { city_id: city.id, name: city.name, connector_id: connector3.id } ] }
                                                                                                                   ]
                                }
                              ]
      end
    end

    context '地方、都道府県*2、市区町村の時' do
      before do
        connector1
        connector2
        connector3
        connector5
      end
      it do
        expect(subject).to eq [
                                {region_id: region.id, name: region.name, connector_id: connector1.id, prefecture: [
                                                                                                                     { prefecture_id: prefecture.id,  name: prefecture.name,  connector_id: connector2.id, city: [ { city_id: city.id, name: city.name, connector_id: connector3.id } ] },
                                                                                                                     { prefecture_id: prefecture2.id, name: prefecture2.name, connector_id: connector5.id, city: [] }
                                                                                                                   ]
                                }
                              ]
      end
    end

    context '地方、都道府県、市区町村*2の時' do
      before do
        connector1
        connector2
        connector3
        connector4
      end
      it do
        expect(subject).to eq [
                                {region_id: region.id, name: region.name, connector_id: connector1.id, prefecture: [
                                                                                                                     { prefecture_id: prefecture.id,  name: prefecture.name,  connector_id: connector2.id, city: [ { city_id: city.id,  name: city.name,  connector_id: connector3.id },
                                                                                                                                                                                                                   { city_id: city2.id, name: city2.name, connector_id: connector4.id }
                                                                                                                                                                                                                 ]
                                                                                                                     }
                                                                                                                    ]
                                }
                              ]
      end
    end

    context '地方*2、都道府県*2、市区町村*2の時' do
      before do
        connector1
        connector2
        connector3
        connector4
        connector5
        connector6
      end
      it do
        expect(subject).to eq [
                                {region_id: region.id, name: region.name, connector_id: connector1.id, prefecture: [
                                                                                                                     { prefecture_id: prefecture.id,  name: prefecture.name,  connector_id: connector2.id, city: [ { city_id: city.id,  name: city.name,  connector_id: connector3.id },
                                                                                                                                                                                                                   { city_id: city2.id, name: city2.name, connector_id: connector4.id }
                                                                                                                                                                                                               ]
                                                                                                                     },
                                                                                                                     { prefecture_id: prefecture2.id, name: prefecture2.name, connector_id: connector5.id, city: [] }
                                                                                                                   ]
                                },
                                {region_id: region2.id, name: region2.name, connector_id: connector6.id, prefecture: []}
                              ]
      end
    end

  end

  describe '#import_and_make' do
    subject { described_class.import_and_make(company, region_name, prefecture_name, city_name) }
    let(:company) { create(:company) }
    let(:region_name) { '関東' }
    let(:prefecture_name) { '東京都' }
    let(:city_name) { '新宿区' }
    let(:region) { create(:region, name: region_name) }
    let(:prefecture) { create(:prefecture, name: prefecture_name) }
    let(:city) { create(:city, name: city_name) }
    # let(:region) { Region.find_by(name: region_name) }
    # let(:prefecture) { Prefecture.find_by(name: prefecture_name) }
    let(:city) { City.find_by(name: city_name) }
    let(:connector1) { AreaConnector.find_by(region: region, prefecture: nil, city: nil) }
    let(:connector2) { AreaConnector.find_by(region: region, prefecture: prefecture, city: nil) }
    let(:connector3) { AreaConnector.find_by(region: region, prefecture: prefecture, city: city) }

    before do
      region
      prefecture
      create(:area_connector, region: region, prefecture: nil, city: nil)
      create(:area_connector, region: region, prefecture: prefecture, city: nil)
    end

    context '何も存在していないとき' do
      it { expect{ subject }.to change(Region, :count).by(0) }
      it { expect{ subject }.to change(Prefecture, :count).by(0) }
      it { expect{ subject }.to change(City, :count).by(1) }
      it { expect{ subject }.to change(AreaConnector, :count).by(1) }
      it { expect{ subject }.to change(CompanyAreaConnector, :count).by(1) }
      it do
        subject
        expect(city).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector3)).to be_present
      end
    end

    context 'エリアがいくつか存在しているとき' do
      let(:city) { create(:city, name: city_name) }

      before do
        city
      end

      it { expect{ subject }.to change(Region, :count).by(0) }
      it { expect{ subject }.to change(Prefecture, :count).by(0) }
      it { expect{ subject }.to change(City, :count).by(0) }
      it { expect{ subject }.to change(AreaConnector, :count).by(1) }
      it { expect{ subject }.to change(CompanyAreaConnector, :count).by(1) }
      it do
        subject
        expect(city).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector3)).to be_present
      end
    end

    context '業種とコネクターがいくつか存在しているとき' do
      let(:city) { create(:city, name: city_name) }

      before do
        city
        create(:area_connector, region: region, prefecture: prefecture, city: city)
      end

      it { expect{ subject }.to change(Region, :count).by(0) }
      it { expect{ subject }.to change(Prefecture, :count).by(0) }
      it { expect{ subject }.to change(City, :count).by(0) }
      it { expect{ subject }.to change(AreaConnector, :count).by(0) }
      it { expect{ subject }.to change(CompanyAreaConnector, :count).by(1) }
      it do
        subject
        expect(city).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector3)).to be_present
      end
    end

    context '業種とコネクター、会社コネクターが存在しているとき' do
      let(:city) { create(:city, name: city_name) }

      before do
        city
        con = create(:area_connector, region: region, prefecture: prefecture, city: city)
        create(:company_area_connector, company: company, area_connector: con)
      end

      it { expect{ subject }.to change(Region, :count).by(0) }
      it { expect{ subject }.to change(Prefecture, :count).by(0) }
      it { expect{ subject }.to change(City, :count).by(0) }
      it { expect{ subject }.to change(AreaConnector, :count).by(0) }
      it { expect{ subject }.to change(CompanyAreaConnector, :count).by(0) }
      it do
        subject
        expect(city).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(CompanyAreaConnector.find_by(company: company, area_connector: connector3)).to be_present
      end
    end
  end
end
