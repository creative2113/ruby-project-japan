require 'rails_helper'

RSpec.describe CompanyCompanyGroup, type: :model do
  describe '#find_by_reserved_group' do
    let_it_be(:group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
    let_it_be(:group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10, lower: 0) }
    let_it_be(:group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 20, lower: 11) }
    let_it_be(:group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 21) }
    let_it_be(:dummy_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 21) }
    let_it_be(:dummy_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 21) }
    let_it_be(:company) { create(:company) }
    let_it_be(:dummy_cg) { create(:company_company_group, company: company, company_group: dummy_group2) }

    context 'groupがない時' do
      it { expect(described_class.find_by_reserved_group(company, 'ないタイトル')).to eq(nil) }
    end

    context 'comapnyがgroupを持ってない時' do
      it { expect(described_class.find_by_reserved_group(company, CompanyGroup::CAPITAL)).to eq(nil) }
    end

    context 'comapnyがgroupを持っている時' do
      let!(:cg) { create(:company_company_group, company: company, company_group: group2) }
      it { expect(described_class.find_by_reserved_group(company, CompanyGroup::CAPITAL)).to eq(cg) }
    end
  end

  describe '#create_connection_to' do
    let_it_be(:group1) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: nil) }
    let_it_be(:group2) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 10_000_000, lower: 0) }
    let_it_be(:group3) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: 100_000_000, lower: 10_000_001) }
    let_it_be(:group4) { create(:company_group, :range, title: CompanyGroup::CAPITAL, grouping_number: CompanyGroup::RESERVED[CompanyGroup::CAPITAL], upper: nil, lower: 100_000_001) }
    let_it_be(:dummy_group1) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 21) }
    let_it_be(:dummy_group2) { create(:company_group, :range, title: CompanyGroup::EMPLOYEE, grouping_number: CompanyGroup::RESERVED[CompanyGroup::EMPLOYEE], upper: nil, lower: 21) }
    let_it_be(:domain) { 'aaa_sample.com' }
    let_it_be(:used_domain) { domain }
    let_it_be(:db_company) { nil }
    let_it_be(:company) { create(:company, domain: domain) }
    let_it_be(:dummy_cg) { create(:company_company_group, company: company, company_group: dummy_group2) }
    let(:base_data) {
      [
        {name: "商号", value: "株式会社AAA", priority: 1, group: 1},
        {name: "title", value: "株式会社AAAのサイト", priority: 1, group: 1},
        {name: "電話", value: '000-0000-1111', priority: 1, group: 1},
        {name: "売り上げ高", value: "100億", priority: 1, group: 1},
        {name: "代表", value: ' 田中 太郎', priority: 1, group: 1},
        {name: "社名", value: '株式会社AAA', priority: 1, group: 1},
        {name: "名古屋支店", value: '住所 愛知県名古屋市千種区5-4-4 03-5555-1111', priority: 1, group: 1},
        {name: "代表電話", value: '00-0000-3333', priority: 1, group: 1},
        {name: "従業員数", value: "100人 グループ全体 300人", priority: 1, group: 1},
        {name: "本社", value: '東京都八王子市南56-7', priority: 1, group: 1},
      ]
    }
    let(:data) {
      base_data << {name: "資本", value: capital_value, priority: 1, group: 1}
      base_data
    }
    let(:company_data) { CompanyData.new("http://#{domain}", data) }
    let(:title) { CompanyGroup::CAPITAL }
    let(:capital_value) { '2億' }
    let(:value) { nil }
    let(:source) { 'corporate_site' }

    before { Timecop.freeze }
    after  { Timecop.return }

    subject { described_class.create_connection_to(title, source, domain: used_domain, db_company: db_company, company_data: company_data, value: value) }

    context 'domainもcompanyもない時' do
      let(:used_domain) { nil }
      let(:db_company) { nil }
      it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
      it { expect(subject).to be_nil }
    end

    context 'domainのcompanyがない時' do
      let!(:used_domain) { 'dummy.com' }
      it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
      it { expect(subject).to be_nil }
    end

    context 'company_groupがない時' do
      let(:title) { CompanyGroup::SALES }
      it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
      it { expect(subject).to be_nil }
    end

    context 'sourceがない時' do
      let(:source) { 'aaa' }
      it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
      it { expect(subject).to be_nil }
    end

    context '新規作成の時' do
      context 'db_companyの時、domain => X' do
        let!(:used_domain) { nil }
        let_it_be(:db_company) { create(:company) }
        let(:source) { 'biz_map' }

        context '資本金の値が不明の時' do
          let(:data) { base_data }
          let(:source) { 'only_register' }

          it { expect{subject}.to change(CompanyCompanyGroup, :count).by(1) }
          it {
            expect(described_class.find_by_reserved_group(db_company, title)).to be_nil
            expect(subject).to be_truthy

            ccg = described_class.find_by_reserved_group(db_company, title)
            expect(ccg.company).to eq db_company
            expect(ccg.company_group).to eq group1
            expect(ccg.source).to eq 'only_register'
            expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['only_register'][:expired_at]).iso8601
          }
        end

        context '値がある時' do
          let(:source) { 'biz_map' }

          it { expect{subject}.to change(CompanyCompanyGroup, :count).by(1) }
          it {
            expect(described_class.find_by_reserved_group(db_company, title)).to be_nil
            expect(subject).to be_truthy

            ccg = described_class.find_by_reserved_group(db_company, title)
            expect(ccg.company).to eq db_company
            expect(ccg.company_group).to eq group4
            expect(ccg.source).to eq 'biz_map'
            expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['biz_map'][:expired_at]).iso8601
          }
        end
      end

      context 'domainの時、db_company => X' do
        let!(:used_domain) { domain }

        context 'company_dataの時、value => X' do
          context '資本金の値が不明の時' do
            let(:data) { base_data }
            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(1) }
            it {
              expect(described_class.find_by_reserved_group(company, title)).to be_nil
              expect(subject).to be_truthy

              ccg = described_class.find_by_reserved_group(company, title)
              expect(ccg.company).to eq company
              expect(ccg.company_group).to eq group1
              expect(ccg.source).to eq 'corporate_site'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
            }
          end

          context '値がある時' do
            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(1) }
            it {
              expect(described_class.find_by_reserved_group(company, title)).to be_nil
              expect(subject).to be_truthy

              ccg = described_class.find_by_reserved_group(company, title)
              expect(ccg.company).to eq company
              expect(ccg.company_group).to eq group4
              expect(ccg.source).to eq 'corporate_site'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
            }
          end
        end

        context 'valueの時、company_data => X' do
          let(:company_data) { nil }

          context '資本金の値が不明の時' do
            let(:value) { nil }
            let(:data) { base_data }
            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(1) }
            it {
              expect(described_class.find_by_reserved_group(company, title)).to be_nil
              expect(subject).to be_truthy

              ccg = described_class.find_by_reserved_group(company, title)
              expect(ccg.company).to eq company
              expect(ccg.company_group).to eq group1
              expect(ccg.source).to eq 'corporate_site'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
            }
          end

          context '値がある時' do
            let(:value) { 5_000_000 }
            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(1) }
            it {
              expect(described_class.find_by_reserved_group(company, title)).to be_nil
              expect(subject).to be_truthy

              ccg = described_class.find_by_reserved_group(company, title)
              expect(ccg.company).to eq company
              expect(ccg.company_group).to eq group2
              expect(ccg.source).to eq 'corporate_site'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
            }
          end
        end
      end
    end

    context '更新の時' do
      describe 'ソースによる更新条件の比較' do
        let!(:used_domain) { nil }
        let_it_be(:db_company) { create(:company) }
        let(:source) { 'biz_map' }

        context '更新される時' do
          context 'company_company_groupが不明の値の時は問答無用で更新する' do
            let(:source) { 'only_register' }
            let(:company_data) { nil }
            let(:value) { '2,000,000' }
            let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group1) }

            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
            it {
              expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
              expect(subject).to be_truthy

              expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
              expect(ccg.reload.company).to eq db_company
              expect(ccg.company_group).to eq group2
              expect(ccg.source).to eq 'only_register'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['only_register'][:expired_at]).iso8601
            }
          end

          context '期限内で、ソースレベルが高い時' do
            let(:source) { 'corporate_site' }
            let(:company_data) { nil }
            let(:value) { '2,000,000' }
            let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group4, source: 'biz_map', expired_at: Time.zone.now + 1.month) }

            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
            it {
              expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
              expect(subject).to be_truthy

              expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
              expect(ccg.reload.company).to eq db_company
              expect(ccg.company_group).to eq group2
              expect(ccg.source).to eq 'corporate_site'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
            }
          end

          context '期限内で、ソースレベルが同じ時' do
            let(:source) { 'biz_map' }
            let(:company_data) { nil }
            let(:value) { '2,000,000' }
            let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group4, source: 'biz_map', expired_at: Time.zone.now + 3.month) }

            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
            it {
              expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
              expect(subject).to be_truthy

              expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
              expect(ccg.reload.company).to eq db_company
              expect(ccg.company_group).to eq group2
              expect(ccg.source).to eq 'biz_map'
              expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['biz_map'][:expired_at]).iso8601
            }
          end
        end

        context '更新されない時' do
          context '期限内で、ソースレベルが低い時' do
            let(:source) { 'biz_map' }
            let(:company_data) { nil }
            let(:value) { '2,000,000' }
            let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group4, source: 'corporate_site', expired_at: Time.zone.now + 1.month) }

            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
            it {
                expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
                expect(ccg.source).to eq 'corporate_site'
              }
          end

          context '期限外だが、ソースレベルが5以上低い時' do
            let(:source) { 'only_register' }
            let(:company_data) { nil }
            let(:value) { '2,000,000' }
            let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group4, source: 'biz_map', expired_at: Time.zone.now - 1.months) }

            it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
            it {
                expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
                expect(ccg.source).to eq 'biz_map'
              }
          end
        end
      end

      context 'db_companyの時' do
        let!(:used_domain) { nil }
        let_it_be(:db_company) { create(:company) }
        let(:source) { 'biz_map' }

        context 'company_dataの時' do
          context '更新の値がある時' do
            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group1) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
                expect(subject).to be_truthy

                expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
                expect(ccg.reload.company).to eq db_company
                expect(ccg.company_group).to eq group4
                expect(ccg.source).to eq 'biz_map'
                expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['biz_map'][:expired_at]).iso8601
              }
            end

            context 'company_company_groupが値のある時' do
              let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group2, source: 'only_register') }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
                expect(subject).to be_truthy

                expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
                expect(ccg.reload.company).to eq db_company
                expect(ccg.company_group).to eq group4
                expect(ccg.source).to eq 'biz_map'
                expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['biz_map'][:expired_at]).iso8601
              }
            end
          end

          context '更新の値がない時' do
            let(:data) { base_data }

            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group1, source: 'only_register') }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
                expect(ccg.source).to eq 'only_register'
              }
            end

            context 'company_company_groupが値のある時' do
              let_it_be(:ccg) { create(:company_company_group, company: db_company, company_group: group2, source: 'only_register') }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(db_company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(db_company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
                expect(ccg.source).to eq 'only_register'
              }
            end
          end
        end
      end

      context 'domainの時' do
        context 'company_dataの時' do
          context '更新の値がある時' do
            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group1) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                expect(subject).to be_truthy

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.company).to eq company
                expect(ccg.company_group).to eq group4
                expect(ccg.source).to eq 'corporate_site'
                expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
              }
            end

            context 'company_company_groupが値のある時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group2, source: 'biz_map') }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                expect(subject).to be_truthy

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.company).to eq company
                expect(ccg.company_group).to eq group4
                expect(ccg.source).to eq 'corporate_site'
                expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
              }
            end
          end

          context '更新の値がない時' do
            let(:data) { base_data }

            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group1) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
              }
            end

            context 'company_company_groupが値のある時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group2) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
              }
            end
          end
        end

        context 'valueの時' do
          let(:company_data) { nil }

          context '更新の値がある時' do
            let(:value) { 20_000_000 }

            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group1) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                expect(subject).to be_truthy

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.company).to eq company
                expect(ccg.company_group).to eq group3
                expect(ccg.source).to eq 'corporate_site'
                expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
              }
            end

            context 'company_company_groupが値のある時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group2) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                expect(subject).to be_truthy

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.company).to eq company
                expect(ccg.company_group).to eq group3
                expect(ccg.source).to eq 'corporate_site'
                expect(ccg.expired_at).to eq (Time.zone.now + described_class.source_list['corporate_site'][:expired_at]).iso8601
              }
            end
          end

          context '更新の値がない時' do
            let(:value) { nil }

            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group1) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
              }
            end

            context 'company_company_groupが値のある時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group2) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
              }
            end
          end

          context '更新の値がおかしい時' do
            let(:value) { 'aaa' }

            context 'company_company_groupが不明の値の時' do
              let_it_be(:ccg) { create(:company_company_group, company: company, company_group: group1) }

              it { expect{subject}.to change(CompanyCompanyGroup, :count).by(0) }
              it {
                expect(described_class.find_by_reserved_group(company, title)).to eq ccg
                updated_at = ccg.updated_at.dup

                expect(subject).to be_nil

                expect(described_class.find_by_reserved_group(company, title).id).to eq ccg.id
                expect(ccg.reload.updated_at).to eq updated_at
              }
            end
          end
        end
      end
    end
  end
end
