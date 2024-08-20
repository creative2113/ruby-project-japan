require 'rails_helper'

RSpec.describe SearchRequest::CorporateSingle, type: :model do
  describe '#create_with_first_status' do
    subject { described_class.create_with_first_status(url: url, request_id: req.id) }
    let(:bef_url) { 'http://www.example.com' }
    let(:bef_req) { create(:request) }
    let(:req) { create(:request) }
    let(:corp_list) { create(:corporate_single_requested_url, url: bef_url, request: bef_req, test: false) }

    before do
      corp_list
    end

    context '同じものがない時' do
      let(:url) { bef_url }

      it do
        expect { subject }.to change(SearchRequest::CorporateSingle, :count).by(1)
        expect(subject.url).to eq url
        expect(subject.request_id).to eq req.id
      end
    end

    context '同じものがある時' do
      let(:url) { bef_url }
      let(:req) { bef_req }

      it do
        expect { subject }.to change(SearchRequest::CorporateSingle, :count).by(0)
        expect(subject.url).to eq bef_url
        expect(subject.request_id).to eq bef_req.id
      end
    end
  end
end