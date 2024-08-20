require 'rails_helper'

RSpec.describe SearchRequest::CorporateList, type: :model do

  describe '#select_test_data' do
    let(:request) { create(:request, test: true) }
    let(:corporate_list_url) { create(:corporate_list_requested_url, request: request, result_attrs: { corporate_list: corporate_list_result.to_json } ) }

    context 'パターン1' do
      let(:corporate_list_result) {
        {
          'org1 aa'  => { '組織名' => 'org1',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org1_tel',  'adr' => 'org1_adr'},
          'org2 aa'  => { '組織名' => 'org2',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org2_tel',  'adr' => 'org2_adr'},
          'org3 aa'  => { '組織名' => 'org3',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org3_tel',  'adr' => 'org3_adr'},
          'org4 aa'  => { '組織名' => 'org4',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org4_tel',  'adr' => 'org4_adr'},
          'org5 aa'  => { '組織名' => 'org5',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org5_tel',  'adr' => 'org5_adr'},
          'org6 bb'  => { '組織名' => 'org6',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org6_tel',  'adr' => 'org6_adr'},
          'org7 bb'  => { '組織名' => 'org7',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org7_tel',  'adr' => 'org7_adr'},
          'org8 bb'  => { '組織名' => 'org8',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org8_tel',  'adr' => 'org8_adr'},
          'org9 bb'  => { '組織名' => 'org9',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org9_tel',  'adr' => 'org9_adr'},
          'org10 bb' => { '組織名' => 'org10', Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org10_tel', 'adr' => 'org10_adr'},
          'org11 cc' => { '組織名' => 'org11', Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org11_tel', 'adr' => 'org11_adr'},
          'org12 cc' => { '組織名' => 'org12', Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org12_tel', 'adr' => 'org12_adr'},
          'org13 cc' => { '組織名' => 'org13', Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org13_tel', 'adr' => 'org13_adr'},
          'org14 cc' => { '組織名' => 'org14', Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org14_tel', 'adr' => 'org14_adr'},
          'org15 cc' => { '組織名' => 'org15', Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org15_tel', 'adr' => 'org15_adr'}

        }

      }
      it 'データが作れていること' do
        expect(corporate_list_url.select_test_data).to eq(
           {"org1 aa"=>{"組織名"=>"org1", "掲載ページ"=>"aa", "tel"=>"org1_tel", "adr"=>"org1_adr"},
            "org2 aa"=>{"組織名"=>"org2", "掲載ページ"=>"aa", "tel"=>"org2_tel", "adr"=>"org2_adr"},
            "org3 aa"=>{"組織名"=>"org3", "掲載ページ"=>"aa", "tel"=>"org3_tel", "adr"=>"org3_adr"},
            "org4 aa"=>{"組織名"=>"org4", "掲載ページ"=>"aa", "tel"=>"org4_tel", "adr"=>"org4_adr"},
            "org9 bb"=>{"組織名"=>"org9", "掲載ページ"=>"bb", "tel"=>"org9_tel", "adr"=>"org9_adr"},
            "org6 bb"=>{"組織名"=>"org6", "掲載ページ"=>"bb", "tel"=>"org6_tel", "adr"=>"org6_adr"},
            "org8 bb"=>{"組織名"=>"org8", "掲載ページ"=>"bb", "tel"=>"org8_tel", "adr"=>"org8_adr"},
            "org7 bb"=>{"組織名"=>"org7", "掲載ページ"=>"bb", "tel"=>"org7_tel", "adr"=>"org7_adr"},
            "org14 cc"=>{"組織名"=>"org14", "掲載ページ"=>"cc", "tel"=>"org14_tel", "adr"=>"org14_adr"},
            "org12 cc"=>{"組織名"=>"org12", "掲載ページ"=>"cc", "tel"=>"org12_tel", "adr"=>"org12_adr"},
            "org13 cc"=>{"組織名"=>"org13", "掲載ページ"=>"cc", "tel"=>"org13_tel", "adr"=>"org13_adr"},
            "org11 cc"=>{"組織名"=>"org11", "掲載ページ"=>"cc", "tel"=>"org11_tel", "adr"=>"org11_adr"}
           }
        )
      end
    end

    context 'パターン2' do
      let(:corporate_list_result) {
          {
            'org1 bb'  => { '組織名' => 'org1',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org1_tel',  'adr' => 'org1_adr'},
            'org2 bb'  => { '組織名' => 'org2',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'bb', 'tel' => 'org2_tel',  'adr' => 'org2_adr'},
            'org3 aa'  => { '組織名' => 'org3',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org3_tel',  'adr' => 'org3_adr'},
            'org4 aa'  => { '組織名' => 'org4',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'aa', 'tel' => 'org4_tel',  'adr' => 'org4_adr'},
            'org5 dd'  => { '組織名' => 'org5',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'dd', 'tel' => 'org5_tel',  'adr' => 'org5_adr'},
            'org6 dd'  => { '組織名' => 'org6',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'dd', 'tel' => 'org6_tel',  'adr' => 'org6_adr'},
            'org7 ee'  => { '組織名' => 'org7',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'ee', 'tel' => 'org7_tel',  'adr' => 'org7_adr'},
            'org8 cc'  => { '組織名' => 'org8',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org8_tel',  'adr' => 'org8_adr'},
            'org9 cc'  => { '組織名' => 'org9',  Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org9_tel',  'adr' => 'org9_adr'},
            'org10 cc' => { '組織名' => 'org10', Analyzer::BasicAnalyzer::ATTR_PAGE => 'cc', 'tel' => 'org10_tel', 'adr' => 'org10_adr'}
          }

        }
      it 'データが作れていること' do
        expect(corporate_list_url.select_test_data).to eq(
           {"org4 aa"=>{"組織名"=>"org4", "掲載ページ"=>"aa", "tel"=>"org4_tel", "adr"=>"org4_adr"},
            "org3 aa"=>{"組織名"=>"org3", "掲載ページ"=>"aa", "tel"=>"org3_tel", "adr"=>"org3_adr"},
            "org1 bb"=>{"組織名"=>"org1", "掲載ページ"=>"bb", "tel"=>"org1_tel", "adr"=>"org1_adr"},
            "org2 bb"=>{"組織名"=>"org2", "掲載ページ"=>"bb", "tel"=>"org2_tel", "adr"=>"org2_adr"},
            "org8 cc"=>{"組織名"=>"org8", "掲載ページ"=>"cc", "tel"=>"org8_tel", "adr"=>"org8_adr"},
            "org10 cc"=>{"組織名"=>"org10", "掲載ページ"=>"cc", "tel"=>"org10_tel", "adr"=>"org10_adr"},
            "org9 cc"=>{"組織名"=>"org9", "掲載ページ"=>"cc", "tel"=>"org9_tel", "adr"=>"org9_adr"},
            "org5 dd"=>{"組織名"=>"org5", "掲載ページ"=>"dd", "tel"=>"org5_tel", "adr"=>"org5_adr"},
            "org6 dd"=>{"組織名"=>"org6", "掲載ページ"=>"dd", "tel"=>"org6_tel", "adr"=>"org6_adr"},
            "org7 ee"=>{"組織名"=>"org7", "掲載ページ"=>"ee", "tel"=>"org7_tel", "adr"=>"org7_adr"}
           }
        )
      end
    end
  end
end
