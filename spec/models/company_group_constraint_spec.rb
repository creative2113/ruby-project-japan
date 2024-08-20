require 'rails_helper'

RSpec.describe CompanyGroupConstraint, type: :model do
  describe '#new' do
    subject { described_class.new(all_headers) }

    context '重複しているヘッダーがある' do
      let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID'] }

      it { expect{ subject }.to raise_error(CompanyGroupConstraint::DuplicatedGroupIDHeaders, '重複しているグループIDが存在しています。') }
    end

    context '重複しているヘッダーがある' do
      let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID_a', 'グループID_a'] }

      it { expect{ subject }.to raise_error(CompanyGroupConstraint::DuplicatedGroupIDHeaders, '重複しているグループIDが存在しています。') }
    end

    context '正常系' do
      let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID_a', 'グループID_b_空欄許可'] }

      it { expect(subject.instance_variable_get('@headers')).to eq ['グループID', 'グループID_a', 'グループID_b_空欄許可'] }
      it { expect(subject.instance_variable_get('@headers_map')).to eq({'グループID' => nil, 'グループID_a' => nil, 'グループID_b_空欄許可' => nil}) }
    end
  end

  shared_context '#checkの異常系の確認' do
    context 'グループIDの値が文字列ではない時' do
      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => 1, 'グループID_a' => '2'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::StrangeGroupID, "グループIDのグループIDは奇妙なIDです。文字列で渡されませんでした。1") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => 2} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::StrangeGroupID, "グループID_aのグループIDは奇妙なIDです。文字列で渡されませんでした。2") }
      end
    end

    context 'グループIDが空欄の時' do
      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '', 'グループID_a' => '2'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::BlankGroupID, "グループIDのグループIDが空欄です。空欄を許可するにはヘッダーに「空欄許可」を加えてください。") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => ''} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::BlankGroupID, "グループID_aのグループIDが空欄です。空欄を許可するにはヘッダーに「空欄許可」を加えてください。") }
      end
    end

    context 'グループIDが整数ではない時' do
      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => 'a', 'グループID_a' => '2'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotPositiveIntegerGroupID, "グループID：グループIDは正の整数でなければいけません。a") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '-1', 'グループID_a' => '2'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotPositiveIntegerGroupID, "グループID：グループIDは正の整数でなければいけません。-1") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '4.3', 'グループID_a' => '2'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotPositiveIntegerGroupID, "グループID：グループIDは正の整数でなければいけません。4.3") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => 'a'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotPositiveIntegerGroupID, "グループID_a：グループIDは正の整数でなければいけません。a") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '-1'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotPositiveIntegerGroupID, "グループID_a：グループIDは正の整数でなければいけません。-1") }
      end

      context do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '5.3'} }
        it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotPositiveIntegerGroupID, "グループID_a：グループIDは正の整数でなければいけません。5.3") }
      end
    end

    describe '初回のグループ設定' do
      context '存在しないグループID' do
        context do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '3', 'グループID_a' => '2'} }
          it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotFoundGroupID, "グループIDのグループIDは存在しないIDです。3") }
        end

        context do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '3'} }
          it { expect{ subject }.to raise_error(CompanyGroupConstraint::NotFoundGroupID, "グループID_aのグループIDは存在しないIDです。3") }
        end
      end
    end

    describe 'すでにグループが設定済みの時' do
      let(:row_data_before) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
      let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
      let(:grouping_number1) { 2 }
      let(:grouping_number2) { 3 }
      before do
        create(:company_group, id: 3, grouping_number: 3)
        create(:company_group, id: 4, grouping_number: 4)
        create(:company_group, id: 5, title: title1, grouping_number: grouping_number1)
        create(:company_group, id: 6, title: title2, grouping_number: grouping_number2)
        create(:company_group, id: 7, title: '違うタイトル1', grouping_number: grouping_number1)
        create(:company_group, id: 8, title: '違うタイトル2', grouping_number: grouping_number2)

        instance.check(row_data_before)
      end

      context '別のグループID' do
        context 'ヘッダ：グループID' do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '3', 'グループID_a' => '2'} }
          it { expect{ subject }.to raise_error(CompanyGroupConstraint::DifferentGroupID, "グループIDのグループIDは違うグループのIDです。3") }
        end

        context 'ヘッダ：グループID_a' do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '4'} }
          it { expect{ subject }.to raise_error(CompanyGroupConstraint::DifferentGroupID, "グループID_aのグループIDは違うグループのIDです。4") }
        end

        context 'ヘッダ：グループID_a' do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '5'} }
          it { expect{ subject }.to raise_error(CompanyGroupConstraint::DifferentGroupID, "グループID_aのグループIDは違うグループのIDです。5") }
        end
      end
    end
  end

  describe '#check' do
    subject { instance.check(row_data) }

    let(:instance) { described_class.new(all_headers) }
    let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID_a'] }
    let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
    let(:title1) { 'title1' }
    let(:title2) { 'title2' }
    let(:grouping_number1) { 1 }
    let(:grouping_number2) { 2 }

    before do
      create(:company_group, id: 1, title: title1, grouping_number: grouping_number1)
      create(:company_group, id: 2, title: title2, grouping_number: grouping_number2)
    end

    it_behaves_like '#checkの異常系の確認'

    context '空欄許可されていて、空欄の時' do
      let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID_a_空欄許可'] }
      let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_b_空欄許可' => ''} }

      it { expect(subject).to be_truthy }
    end

    describe '初回のグループ設定' do
      context '同じグループがない時' do
        before do
          create(:company_group, id: 3, grouping_number: 3)
          create(:company_group, id: 4, grouping_number: 4)
        end

        context do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
          it { expect(subject).to be_truthy }
          it do
            subject
            expect(instance.instance_variable_get('@headers_map')['グループID']).to eq({ group: CompanyGroup.find_by(id: 1), same_group_ids: [1]})
          end

          it do
            subject
            expect(instance.instance_variable_get('@headers_map')['グループID_a']).to eq({ group: CompanyGroup.find_by(id: 2), same_group_ids: [2]})
          end
        end
      end

      context 'grouping_numberで同じグループがある時' do
        before do
          create(:company_group, id: 3, grouping_number: 3)
          create(:company_group, id: 4, grouping_number: 4)
          create(:company_group, id: 5, title: 'a1', grouping_number: grouping_number2)
          create(:company_group, id: 6, title: 'a2', grouping_number: grouping_number1)
          create(:company_group, id: 7, title: 'a3', grouping_number: grouping_number2)
        end

        context do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
          it { expect(subject).to be_truthy }
          it do
            subject
            expect(instance.instance_variable_get('@headers_map')['グループID']).to eq({ group: CompanyGroup.find_by(id: 1), same_group_ids: [1,6]})
          end

          it do
            subject
            expect(instance.instance_variable_get('@headers_map')['グループID_a']).to eq({ group: CompanyGroup.find_by(id: 2), same_group_ids: [2,5,7]})
          end
        end
      end

      context 'titleで同じグループがある時' do
        before do
          create(:company_group, id: 3, grouping_number: 3)
          create(:company_group, id: 4, grouping_number: 4)
          create(:company_group, id: 5, title: title2, grouping_number: grouping_number2)
          create(:company_group, id: 6, title: title1, grouping_number: grouping_number1)
          create(:company_group, id: 7, title: title2, grouping_number: grouping_number2)
        end

        context do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
          it { expect(subject).to be_truthy }
          it 'タイトルが共通のものが選ばれること。' do
            subject
            expect(instance.instance_variable_get('@headers_map')['グループID']).to eq({ group: CompanyGroup.find_by(id: 1), same_group_ids: [1,6]})
          end

          it 'タイトルが共通のものが選ばれること。' do
            subject
            expect(instance.instance_variable_get('@headers_map')['グループID_a']).to eq({ group: CompanyGroup.find_by(id: 2), same_group_ids: [2,5,7]})
          end
        end
      end
    end

    describe 'すでにグループが設定済みの時' do
      let(:row_data_before) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
      let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
      let(:grouping_number1) { 2 }
      let(:grouping_number2) { 3 }
      before do
        create(:company_group, id: 3, grouping_number: 3)
        create(:company_group, id: 4, grouping_number: 4)
        create(:company_group, id: 5, title: title1, grouping_number: grouping_number1)
        create(:company_group, id: 6, title: title2, grouping_number: grouping_number2)
        create(:company_group, id: 7, title: '違うタイトル1', grouping_number: grouping_number1)
        create(:company_group, id: 8, title: '違うタイトル2', grouping_number: grouping_number2)

        instance.check(row_data_before)
      end

      context '正常系' do
        context '自身と同じグループID' do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
          it { expect(subject).to be_truthy }
        end

        context '同じグループのグループID' do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '5', 'グループID_a' => '6'} }
          it { expect(subject).to be_truthy }
        end

        context '同じグループのグループID' do
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '7', 'グループID_a' => '8'} }
          it { expect(subject).to be_truthy }
        end
      end
    end
  end

  describe '#select_group_ids' do
    subject { instance.select_group_ids(row_data) }

    let(:instance) { described_class.new(all_headers) }
    let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID_a'] }
    let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
    let(:title1) { 'title1' }
    let(:title2) { 'title2' }
    let(:grouping_number1) { 1 }
    let(:grouping_number2) { 2 }

    before do
      create(:company_group, id: 1, title: title1, grouping_number: grouping_number1)
      create(:company_group, id: 2, title: title2, grouping_number: grouping_number2)
    end

    it_behaves_like '#checkの異常系の確認'

    context '正常系' do
      before do
        create(:company_group, id: 3, grouping_number: 3)
        create(:company_group, id: 4, grouping_number: 4)
        create(:company_group, id: 5, title: '違うタイトル1', grouping_number: grouping_number1)
        create(:company_group, id: 6, title: '違うタイトル2', grouping_number: grouping_number2)
        create(:company_group, id: 7, title: title1, grouping_number: grouping_number1)
        create(:company_group, id: 8, title: title2, grouping_number: grouping_number2)
      end

      context '空欄許可されていて、空欄の時' do
        context do
          let(:all_headers) { ['aa', 'bb', 'cc', 'グループID', 'グループID_a_空欄許可'] }
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_b_空欄許可' => ''} }

          it { expect(subject).to eq [1] }
        end

        context do
          let(:all_headers) { ['aa', 'bb', 'cc', 'グループID_空欄許可', 'グループID_a_空欄許可'] }
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID_空欄許可' => '', 'グループID_a' => '2'} }

          it { expect(subject).to eq [2] }
        end

        context do
          let(:all_headers) { ['aa', 'bb', 'cc', 'グループID_空欄許可', 'グループID_a_空欄許可'] }
          let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID_空欄許可' => '', 'グループID_a_空欄許可' => ''} }

          it { expect(subject).to eq [] }
        end
      end

      context '自身のグループIDの時' do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '2'} }
        it { expect(subject).to eq [1,2] }
      end

      context '同じグループのグループIDも混ざっている時' do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '6'} }
        it { expect(subject).to eq [1,6] }
      end

      context '同じグループのグループIDも混ざっている時' do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '1', 'グループID_a' => '8'} }
        it { expect(subject).to eq [1,8] }
      end

      context '同じグループのグループIDも混ざっている時' do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '5', 'グループID_a' => '2'} }
        it { expect(subject).to eq [5,2] }
      end

      context '同じグループのグループIDも混ざっている時' do
        let(:row_data) { {'aa' => 1, 'bb' => 1, 'cc' => 1, 'グループID' => '7', 'グループID_a' => '2'} }
        it { expect(subject).to eq [7,2] }
      end
    end
  end
end