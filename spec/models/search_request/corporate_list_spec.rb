require 'rails_helper'

RSpec.describe SearchRequest::CorporateList, type: :model do
  describe '#create_with_first_status' do
    subject { described_class.create_with_first_status(url: url, request_id: req.id, test: false) }
    let(:bef_url) { 'http://www.example.com' }
    let(:bef_req) { create(:request) }
    let(:req) { create(:request) }
    let!(:corp_list) { create(:corporate_list_requested_url, url: bef_url, request: bef_req, test: false) }

    context '同じものがない時' do
      let(:url) { bef_url }

      it do
        expect { subject }.to change(SearchRequest::CorporateList, :count).by(1)
        expect(subject.url).to eq url
        expect(subject.request_id).to eq req.id
      end
    end

    context '同じものがある時' do
      let(:url) { bef_url }
      let(:req) { bef_req }

      it do
        expect { subject }.to change(SearchRequest::CorporateList, :count).by(0)
        expect(subject.url).to eq bef_url
        expect(subject.request_id).to eq bef_req.id
      end
    end
  end

  describe '#separation_info' do
    subject { corp_list.separation_info }
    let_it_be(:req) { create(:request) }
    let_it_be(:corp_list) { create(:corporate_list_requested_url, url: 'http://www.example.com', request: req) }
    let!(:result) { create(:result, corporate_list: corporate_list_result, requested_url: corp_list) }

    context 'corporate_list_resultがnil' do
      let(:corporate_list_result) { nil }

      it do
        expect(subject).to eq({})
      end
    end

    context '仕切り情報がない' do
      let(:corporate_list_result) {
        { 'aaa' => {
            'a' => 'a1',
            'b' => 'b1',
            'c' => 'c1'
          },
          'bbb' => {
            'a' => 'a2',
            'b' => 'b2',
            'c' => 'c2'
          },
          'ccc' => {
            'a' => 'a3',
            'b' => 'b3',
            'c' => 'c3'
          }
        }.to_json
      }

      it do
        expect(subject).to eq({})
      end
    end

    context '仕切り情報がある' do
      let(:corporate_list_result) {
        { 'aaa' => {
            'a' => 'a1',
            'b' => 'b1',
            '仕切り情報' => 'あいう',
            'c' => 'c1'
          },
          'bbb' => {
            'a' => 'a2',
            'b' => 'b2',
            '仕切り情報' => 'かきく',
            'c' => 'c2'
          },
          'ccc' => {
            'a' => 'a3',
            'b' => 'b3',
            '仕切り情報' => 'あいう',
            'c' => 'c3'
          }
        }.to_json
      }

      it do
        expect(subject).to eq({'仕切り情報' => ['あいう', 'かきく']})
      end
    end

    context '仕切り情報がある' do
      let(:corporate_list_result) {
        { 'aaa' => {
            'a' => 'a1',
            'b' => 'b1',
            '仕切り情報 1' => 'あいう',
            '仕切り情報 2' => 'さしす',
            'c' => 'c1'
          },
          'bbb' => {
            'a' => 'a2',
            'b' => 'b2',
            '仕切り情報 1' => 'かきく',
            '仕切り情報 2' => 'さしす',
            'c' => 'c2'
          },
          'ccc' => {
            'a' => 'a3',
            'b' => 'b3',
            '仕切り情報 1' => 'あいう',
            '仕切り情報 2' => 'たちつ',
            'c' => 'c3'
          }
        }.to_json
      }

      it do
        expect(subject).to eq({'仕切り情報 1' => ['あいう', 'かきく'], '仕切り情報 2' => ['さしす', 'たちつ']})
      end
    end
  end
end
