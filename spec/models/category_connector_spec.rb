require 'rails_helper'

RSpec.describe CategoryConnector, type: :model do

  describe '#check_blank' do
    let(:large) { create(:large_category, name: '製造業') }
    let(:middle) { create(:middle_category, name: '金属') }
    let(:small) { create(:small_category, name: 'アルミ') }
    let(:detail) { create(:detail_category, name: 'アルミ缶') }

    it do
      expect { CategoryConnector.create!(large_category: large, middle_category: nil, small_category: nil, detail_category: detail) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: large, middle_category: middle, small_category: nil, detail_category: detail) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: nil, small_category: nil, detail_category: detail) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: middle, small_category: nil, detail_category: detail) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: nil, small_category: small, detail_category: detail) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: middle, small_category: small, detail_category: detail) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: large, middle_category: nil, small_category: small) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: nil, small_category: small) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: middle, small_category: small) }.to raise_error(ActiveRecord::RecordInvalid)
      expect { CategoryConnector.create!(large_category: nil, middle_category: middle, small_category: nil) }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe '#find_or_create' do
    subject { described_class.find_or_create(large, middle, small, nil) }
    let(:large) { create(:large_category, name: '製造業') }
    let(:middle) { create(:middle_category, name: '金属') }
    let(:small) { create(:small_category, name: 'アルミ') }
    let(:connector) { create(:category_connector, large_category: large, middle_category: middle, small_category: small) }

    context '存在しているとき' do
      before do
        connector
      end

      it { expect{ subject }.to change(CategoryConnector, :count).by(0) }
      it { expect(subject).to eq connector }
    end

    context '存在していないとき' do
      it { expect{ subject }.to change(CategoryConnector, :count).by(1) }
      it { expect(subject).to eq CategoryConnector.last }
    end
  end

  describe '#make_where_clause' do
    subject { described_class.make_where_clause(connector_ids) }
    let(:large) { create(:large_category, name: '製造業') }
    let(:middle) { create(:middle_category, name: '金属') }
    let(:small) { create(:small_category, name: 'アルミ') }
    let(:detail) { create(:detail_category, name: 'アルミ缶') }
    let(:connector1) { create(:category_connector, large_category: large, middle_category: nil, small_category: nil) }
    let(:connector2) { create(:category_connector, large_category: large, middle_category: middle, small_category: nil) }
    let(:connector3) { create(:category_connector, large_category: large, middle_category: middle, small_category: small) }
    let(:connector4) { create(:category_connector, large_category: large, middle_category: middle, small_category: small, detail_category: detail) }

    context do
      let(:connector_ids) { [connector1.id] }
      before do
        connector1
      end
      it do
        expect(subject).to eq "( category_connectors.large_category_id = #{large.id}  ) "
      end
    end

    context do
      let(:connector_ids) { [connector1.id, connector2.id] }
      before do
        connector1
        connector2
      end
      it do
        expect(subject).to eq "( category_connectors.large_category_id = #{large.id}  ) OR ( category_connectors.large_category_id = #{large.id} AND category_connectors.middle_category_id = #{middle.id}  ) "
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
        expect(subject).to eq "( category_connectors.large_category_id = #{large.id}  ) OR ( category_connectors.large_category_id = #{large.id} AND category_connectors.middle_category_id = #{middle.id}  ) OR " +
                              "( category_connectors.large_category_id = #{large.id} AND category_connectors.middle_category_id = #{middle.id} AND category_connectors.small_category_id = #{small.id}  ) "
      end
    end

    context do
      let(:connector_ids) { [connector1.id, connector2.id, connector3.id , connector4.id] }
      before do
        connector1
        connector2
        connector3
        connector4
      end
      it do
        expect(subject).to eq "( category_connectors.large_category_id = #{large.id}  ) OR ( category_connectors.large_category_id = #{large.id} AND category_connectors.middle_category_id = #{middle.id}  ) OR " +
                              "( category_connectors.large_category_id = #{large.id} AND category_connectors.middle_category_id = #{middle.id} AND category_connectors.small_category_id = #{small.id}  ) OR " +
                              "( category_connectors.large_category_id = #{large.id} AND category_connectors.middle_category_id = #{middle.id} AND category_connectors.small_category_id = #{small.id} AND category_connectors.detail_category_id = #{detail.id}  ) "
      end
    end
  end

  describe '#find_all_category_comb' do
    subject { described_class.find_all_category_comb }
    let(:large) { create(:large_category, name: '製造業') }
    let(:large2) { create(:large_category, name: '小売') }
    let(:middle) { create(:middle_category, name: '金属') }
    let(:middle2) { create(:middle_category, name: '食品') }
    let(:small) { create(:small_category, name: 'アルミ') }
    let(:small2) { create(:small_category, name: '鉄鋼') }
    let(:connector1) { create(:category_connector, large_category: large, middle_category: nil, small_category: nil) }
    let(:connector2) { create(:category_connector, large_category: large, middle_category: middle, small_category: nil) }
    let(:connector3) { create(:category_connector, large_category: large, middle_category: middle, small_category: small) }
    let(:connector4) { create(:category_connector, large_category: large, middle_category: middle, small_category: small2) }
    let(:connector5) { create(:category_connector, large_category: large, middle_category: middle2, small_category: nil) }
    let(:connector6) { create(:category_connector, large_category: large2, middle_category: nil, small_category: nil) }

    context 'ラージだけの時' do
      before do
        connector1
      end
      it do
        expect(subject).to eq [{large_id: large.id, name: large.name, connector_id: connector1.id, middle: []}]
      end
    end

    context 'ラージ、ミドルだけの時' do
      before do
        connector1
        connector2
      end
      it do
        expect(subject).to eq [{large_id: large.id, name: large.name, connector_id: connector1.id, middle: [{middle_id: middle.id, name: middle.name, connector_id: connector2.id, small: []}]}]
      end
    end

    context 'ラージ、ミドル、スモールの時' do
      before do
        connector1
        connector2
        connector3
      end
      it do
        expect(subject).to eq [
                                {large_id: large.id, name: large.name, connector_id: connector1.id, middle: [
                                                                                                              { middle_id: middle.id, name: middle.name, connector_id: connector2.id, small: [ { small_id: small.id, name: small.name, connector_id: connector3.id } ] }
                                                                                                            ]
                                }
                              ]
      end
    end

    context 'ラージ、ミドル*2、スモールの時' do
      before do
        connector1
        connector2
        connector3
        connector5
      end
      it do
        expect(subject).to eq [
                                {large_id: large.id, name: large.name, connector_id: connector1.id, middle: [
                                                                                                              { middle_id: middle.id,  name: middle.name,  connector_id: connector2.id, small: [ { small_id: small.id, name: small.name, connector_id: connector3.id } ] },
                                                                                                              { middle_id: middle2.id, name: middle2.name, connector_id: connector5.id, small: [] }
                                                                                                            ]
                                }
                              ]
      end
    end

    context 'ラージ、ミドル、スモール*2の時' do
      before do
        connector1
        connector2
        connector3
        connector4
      end
      it do
        expect(subject).to eq [
                                {large_id: large.id, name: large.name, connector_id: connector1.id, middle: [
                                                                                                              { middle_id: middle.id, name: middle.name, connector_id: connector2.id, small: [ { small_id: small.id,  name: small.name,  connector_id: connector3.id },
                                                                                                                                                                                               { small_id: small2.id, name: small2.name, connector_id: connector4.id }
                                                                                                                                                                                             ]
                                                                                                              }
                                                                                                            ]
                                }
                              ]
      end
    end

    context 'ラージ*2、ミドル*2、スモール*2の時' do
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
                                {large_id: large.id, name: large.name, connector_id: connector1.id, middle: [
                                                                                                              { middle_id: middle.id,  name: middle.name,  connector_id: connector2.id, small: [ { small_id: small.id,  name: small.name,  connector_id: connector3.id },
                                                                                                                                                                                                 { small_id: small2.id, name: small2.name, connector_id: connector4.id }
                                                                                                                                                                                             ]
                                                                                                              },
                                                                                                              { middle_id: middle2.id, name: middle2.name, connector_id: connector5.id, small: [] }
                                                                                                            ]
                                },
                                {large_id: large2.id, name: large2.name, connector_id: connector6.id, middle: []}
                              ]
      end
    end

  end

  describe '#import_and_make' do
    subject { described_class.import_and_make(company, large, middle, small, detail) }
    let(:company) { create(:company) }
    let(:large) { '製造業' }
    let(:middle) { '金属' }
    let(:small) { 'アルミ' }
    let(:detail) { 'アルミ缶' }
    let(:large_category) { LargeCategory.find_by(name: large) }
    let(:middle_category) { MiddleCategory.find_by(name: middle) }
    let(:small_category) { SmallCategory.find_by(name: small) }
    let(:detail_category) { DetailCategory.find_by(name: detail) }
    let(:connector1) { CategoryConnector.find_by(large_category: large_category, middle_category: nil, small_category: nil, detail_category: nil) }
    let(:connector2) { CategoryConnector.find_by(large_category: large_category, middle_category: middle_category, small_category: nil, detail_category: nil) }
    let(:connector3) { CategoryConnector.find_by(large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: nil) }
    let(:connector4) { CategoryConnector.find_by(large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: detail_category) }

    context '何も存在していないとき' do
      it { expect{ subject }.to change(LargeCategory, :count).by(1) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(1) }
      it { expect{ subject }.to change(SmallCategory, :count).by(1) }
      it { expect{ subject }.to change(DetailCategory, :count).by(1) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(4) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(1) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present
      end
    end

    context '業種がいくつか存在しているとき' do
      let(:middle_category) { create(:middle_category, name: middle) }
      let(:small_category) { create(:small_category, name: small) }

      before do
        middle_category
        small_category
      end

      it { expect{ subject }.to change(LargeCategory, :count).by(1) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
      it { expect{ subject }.to change(SmallCategory, :count).by(0) }
      it { expect{ subject }.to change(DetailCategory, :count).by(1) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(4) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(1) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present
      end
    end

    context '業種とコネクターがいくつか存在しているとき' do
      let(:large_category) { create(:large_category, name: large) }
      let(:middle_category) { create(:middle_category, name: middle) }

      before do
        large_category
        middle_category
        create(:category_connector, large_category: large_category, middle_category: nil, small_category: nil, detail_category: nil)
        con = create(:category_connector, large_category: large_category, middle_category: middle_category, small_category: nil, detail_category: nil)
        create(:company_category_connector, company: company, category_connector: con)
      end

      it { expect{ subject }.to change(LargeCategory, :count).by(0) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
      it { expect{ subject }.to change(SmallCategory, :count).by(1) }
      it { expect{ subject }.to change(DetailCategory, :count).by(1) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(2) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(1) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present
      end
    end

    context '業種とコネクターがいくつか存在しているとき' do
      let(:large_category) { create(:large_category, name: large) }
      let(:middle_category) { create(:middle_category, name: middle) }
      let(:small_category) { create(:small_category, name: small) }
      let(:detail_category) { create(:detail_category, name: detail) }

      before do
        large_category
        middle_category
        small_category
        detail_category
        create(:category_connector, large_category: large_category, middle_category: nil, small_category: nil, detail_category: nil)
        create(:category_connector, large_category: large_category, middle_category: middle_category, small_category: nil, detail_category: nil)
        create(:category_connector, large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: nil)
        create(:category_connector, large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: detail_category)
      end

      it { expect{ subject }.to change(LargeCategory, :count).by(0) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
      it { expect{ subject }.to change(SmallCategory, :count).by(0) }
      it { expect{ subject }.to change(DetailCategory, :count).by(0) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(0) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(1) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present
      end
    end

    context '業種とコネクター、会社コネクターが存在しているとき' do
      let(:large_category) { create(:large_category, name: large) }
      let(:middle_category) { create(:middle_category, name: middle) }
      let(:small_category) { create(:small_category, name: small) }
      let(:detail_category) { create(:detail_category, name: detail) }

      before do
        large_category
        middle_category
        small_category
        detail_category
        create(:category_connector, large_category: large_category, middle_category: nil, small_category: nil, detail_category: nil)
        con = create(:category_connector, large_category: large_category, middle_category: middle_category, small_category: small_category, detail_category: detail_category)
        create(:company_category_connector, company: company, category_connector: con)
      end

      it { expect{ subject }.to change(LargeCategory, :count).by(0) }
      it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
      it { expect{ subject }.to change(SmallCategory, :count).by(0) }
      it { expect{ subject }.to change(DetailCategory, :count).by(0) }
      it { expect{ subject }.to change(CategoryConnector, :count).by(2) }
      it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(0) }
      it do
        subject
        expect(large_category).to be_present
        expect(middle_category).to be_present
        expect(small_category).to be_present
        expect(detail_category).to be_present
        expect(connector1).to be_present
        expect(connector2).to be_present
        expect(connector3).to be_present
        expect(connector4).to be_present
        expect(CompanyCategoryConnector.find_by(company: company, category_connector: connector4)).to be_present
      end
    end
  end
end
