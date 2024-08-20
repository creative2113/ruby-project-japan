require 'rails_helper'

RSpec.describe BulkInserter, type: :model do
  before { Timecop.freeze }

  after { Timecop.return }

  describe 'SearchRequest::CompanyInfo' do
    let(:inserter) { described_class.new(SearchRequest::CompanyInfo) }

    describe '#add' do
      let(:attr1) { { url: 'aaa.com', status: 0, finish_status: 0, request_id: 8 } }
      let(:attr2) { { url: 'bbb.com', status: 0, finish_status: 0, request_id: 8 } }
      let(:attr3) { { url: 'ccc.com', status: 0, finish_status: 0, request_id: 9 } }

      context '挿入が一つだけの時' do
        it do
          inserter.add(attr1)
          attr1.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})
          expect(inserter.instance_variable_get("@request_id")).to eq 8
          expect(inserter.instance_variable_get("@attrs")).to eq [attr1]
        end
      end

      context '挿入が２つの時' do
        it do
          inserter.add(attr1)
          inserter.add(attr2)
          attr1.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})
          attr2.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})

          expect(inserter.instance_variable_get("@request_id")).to eq 8
          expect(inserter.instance_variable_get("@attrs")).to eq [attr1, attr2]
        end
      end

      context 'request_idが異なるとき' do
        it do
          inserter.add(attr1)
          attr1.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})

          expect{ inserter.add(attr3) }.to raise_error(RuntimeError, 'request_idが異なります')
          expect(inserter.instance_variable_get("@attrs")).to eq [attr1]
        end
      end  
    end

    describe '#execute' do
      subject { inserter.execute! }
      let(:request) { create(:request) }
      let(:attr1) { { url: 'aaa.com', status: 0, finish_status: 0, request_id: request.id } }
      let(:attr2) { { url: 'bbb.com', status: 1, finish_status: 1, request_id: request.id } }
      let(:attr3) { { url: 'ccc.com', status: 2, finish_status: 2, request_id: request.id } }

      before do
        create(:company_info_requested_url)
        create(:company_info_requested_url)
        inserter.add(attr1)
        inserter.add(attr2)
        inserter.add(attr3)
      end

      context '成功した時' do
        it { expect{subject}.to change(SearchRequest::CompanyInfo, :count).by(3) }
        it { expect{subject}.to change(request.company_info_urls, :count).by(3) }
        it { expect{subject}.to change(Result, :count).by(3) }
        it do
          expect(request.company_info_urls.count).to eq 0

          subject

          company_info_urls = request.company_info_urls.eager_load(:result)

          expect(company_info_urls.count).to eq 3

          expect(company_info_urls[0].url).to eq 'aaa.com'
          expect(company_info_urls[0].status).to eq 0
          expect(company_info_urls[0].finish_status).to eq 0
          expect(company_info_urls[1].url).to eq 'bbb.com'
          expect(company_info_urls[1].status).to eq 1
          expect(company_info_urls[1].finish_status).to eq 1
          expect(company_info_urls[2].url).to eq 'ccc.com'
          expect(company_info_urls[2].status).to eq 2
          expect(company_info_urls[2].finish_status).to eq 2

          expect(company_info_urls[0].result).to eq Result.last(3)[0]
          expect(company_info_urls[1].result).to eq Result.last(3)[1]
          expect(company_info_urls[2].result).to eq Result.last(3)[2]
        end
      end

      context '失敗した時' do
        before do
          allow(Result).to receive(:insert_all!).and_raise('Dummy Error')
        end
        it { expect{subject}.to raise_error(RuntimeError).and change(SearchRequest::CompanyInfo, :count).by(0) }
        it { expect{subject}.to raise_error(RuntimeError).and change(request.company_info_urls, :count).by(0) }
        it { expect{subject}.to raise_error(RuntimeError).and change(Result, :count).by(0) }
      end
    end
  end

  describe 'TmpCompanyInfoUrl' do
    let(:inserter) { described_class.new(TmpCompanyInfoUrl) }

    describe '#add' do
      let(:attr1) { { url: 'aaa.com', bunch_id: 0, organization_name: 'aaa', corporate_list_result: 'aaa', request_id: 8 } }
      let(:attr2) { { url: 'bbb.com', bunch_id: 0, organization_name: 'bbb', corporate_list_result: 'bbb', request_id: 8 } }

      context '挿入が一つだけの時' do
        it do
          inserter.add(attr1)
          attr1.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})
          expect(inserter.instance_variable_get("@attrs")).to eq [attr1]
        end
      end

      context '挿入が２つの時' do
        it do
          inserter.add(attr1)
          inserter.add(attr2)
          attr1.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})
          attr2.merge!({created_at: Time.zone.now, updated_at: Time.zone.now})

          expect(inserter.instance_variable_get("@attrs")).to eq [attr1, attr2]
        end
      end
    end

    describe '#execute' do
      subject { inserter.execute! }
      let(:request) { create(:request) }
      let(:attr1) { { url: 'aaa.com', bunch_id: 3, organization_name: 'aaa', corporate_list_result: 'result_aaa', request_id: request.id } }
      let(:attr2) { { url: 'bbb.com', bunch_id: 2, organization_name: 'bbb', corporate_list_result: 'result_bbb', request_id: request.id } }
      let(:attr3) { { url: 'ccc.com', bunch_id: 1, organization_name: 'ccc', corporate_list_result: 'result_ccc', request_id: request.id } }

      before do
        inserter.add(attr1)
        inserter.add(attr2)
        inserter.add(attr3)
      end

      context '成功した時' do
        it { expect{subject}.to change(TmpCompanyInfoUrl, :count).by(3) }
        it { expect{subject}.to change(request.tmp_company_info_urls, :count).by(3) }
        it do
          expect(request.tmp_company_info_urls.count).to eq 0

          subject

          tmp_company_info_urls = request.tmp_company_info_urls.order(:id)

          expect(tmp_company_info_urls.count).to eq 3

          expect(tmp_company_info_urls[0].url).to eq 'aaa.com'
          expect(tmp_company_info_urls[0].bunch_id).to eq 3
          expect(tmp_company_info_urls[0].organization_name).to eq 'aaa'
          expect(tmp_company_info_urls[0].corporate_list_result).to eq 'result_aaa'
          expect(tmp_company_info_urls[0].request_id).to eq request.id
          expect(tmp_company_info_urls[1].url).to eq 'bbb.com'
          expect(tmp_company_info_urls[1].bunch_id).to eq 2
          expect(tmp_company_info_urls[1].organization_name).to eq 'bbb'
          expect(tmp_company_info_urls[1].corporate_list_result).to eq 'result_bbb'
          expect(tmp_company_info_urls[1].request_id).to eq request.id
          expect(tmp_company_info_urls[2].url).to eq 'ccc.com'
          expect(tmp_company_info_urls[2].bunch_id).to eq 1
          expect(tmp_company_info_urls[2].organization_name).to eq 'ccc'
          expect(tmp_company_info_urls[2].corporate_list_result).to eq 'result_ccc'
          expect(tmp_company_info_urls[2].request_id).to eq request.id
        end
      end

      context '失敗した時' do
        let(:attr3) { { url: 'ccc.com', bunch_id: nil, organization_name: 'ccc', corporate_list_result: 'result_ccc', request_id: request.id } }

        it { expect{subject}.to raise_error(ActiveRecord::NotNullViolation).and change(TmpCompanyInfoUrl, :count).by(0) }
        it { expect{subject}.to raise_error(ActiveRecord::NotNullViolation).and change(request.tmp_company_info_urls, :count).by(0) }
      end    
    end
  end
end