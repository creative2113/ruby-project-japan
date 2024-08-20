require 'rails_helper'

RSpec.describe WorkerCommonUtil, type: :worker do
  class TestWorkerClass
    include WorkerCommonUtil
  end

  describe '#set_crawl_config' do
    subject { test_class_obj.set_crawl_config(crawler) }

    let(:test_class_obj) { TestWorkerClass.new }
    let(:crawler) { Crawler::CorporateList.new(start_url) }
    let(:domain) { 'example.com' }
    let(:config) { create(:list_crawl_config, domain: domain, corporate_list_config: opt_corporate_list_config.to_json, corporate_individual_config: opt_corporate_individual_config.to_json) }
    let(:dummy_config) { create(:list_crawl_config, domain: 'dummy.com') }
    let(:opt_corporate_list_config) { {'a' => {'url' => 'a'}, 'b' => {'url' => 'b'}} }
    let(:opt_corporate_individual_config) { {'a1' => {'url' => 'a'}, 'b1' => {'url' => 'b'}} }

    let(:request) { create(:request, corporate_list_site_start_url: start_url,
                                     corporate_list_config: corporate_list_config,
                                     corporate_individual_config: corporate_individual_config) }
    let(:start_url) { "https:#{domain}/aaa/bbb/ccc" }
    let(:corporate_list_config) { nil }
    let(:corporate_individual_config) { nil }

    before do
      config
      dummy_config
      test_class_obj.instance_variable_set(:@req, request)
      test_class_obj.instance_variable_set(:@domain, domain)
    end

    context 'corporate_configがある時' do
      context 'corporate_list_configがある時' do
        let(:corporate_list_config) { {'c' => {'url' => 'a'}, 'd' => {'url' => 'b'}}.to_json }

        it do
          subject
          expect(test_class_obj.instance_variable_get('@opt')).to be_nil
          expect(crawler.instance_variable_get('@list_page_config')).to eq Json2.parse(corporate_list_config, symbolize: false)
        end
      end

      context 'corporate_individual_configがある時' do
        let(:corporate_individual_config) { {'e' => {'url' => 'a'}, 'f' => {'url' => 'b'}}.to_json }

        it do
          subject
          expect(test_class_obj.instance_variable_get('@opt')).to be_nil
          expect(crawler.instance_variable_get('@individual_page_config')).to eq Json2.parse(corporate_individual_config, symbolize: false)
        end
      end

      context 'corporate_list_configとcorporate_individual_configがある時' do
        let(:corporate_list_config) { {'c' => {'url' => 'a'}, 'd' => {'url' => 'b'}}.to_json }
        let(:corporate_individual_config) { {'e' => {'url' => 'a'}, 'f' => {'url' => 'b'}}.to_json }

        it do
          subject
          expect(test_class_obj.instance_variable_get('@opt')).to be_nil
          expect(crawler.instance_variable_get('@list_page_config')).to eq Json2.parse(corporate_list_config, symbolize: false)
          expect(crawler.instance_variable_get('@individual_page_config')).to eq Json2.parse(corporate_individual_config, symbolize: false)
        end
      end
    end

    context 'corporate_list_configがない時' do

      context 'config_optionがない時' do
        let(:config) { create(:list_crawl_config, domain: 'aa.com') }

        it do
          subject
          expect(test_class_obj.instance_variable_get('@opt')).to be_nil
          expect(crawler.instance_variable_get('@list_page_config')).to be_nil
          expect(crawler.instance_variable_get('@individual_page_config')).to be_nil
        end
      end

      context 'config_optionがある時' do
        it do
          subject
          expect(test_class_obj.instance_variable_get('@opt')).to eq config
          expect(crawler.instance_variable_get('@list_page_config')).to eq opt_corporate_list_config
          expect(crawler.instance_variable_get('@individual_page_config')).to eq opt_corporate_individual_config
        end
      end
    end
  end

  describe '#select_crawl_options' do
    subject { test_class_obj.select_crawl_options(domain) }

    let(:test_class_obj) { TestWorkerClass.new }
    let(:domain) { 'example.com' }
    let(:config) { create(:list_crawl_config, domain: domain) }
    let(:dummy_config) { create(:list_crawl_config, domain: 'dummy.com') }

    before do
      config
      dummy_config
    end

    context 'ListCrawlConfigがないとき' do
      let(:config) { create(:list_crawl_config, domain: 'aa.com') }

      it do
        expect(subject).to be_nil
      end
    end

    context 'ListCrawlConfigが一つあるとき' do
      it do
        expect(subject).to eq config
      end
    end

    context 'ListCrawlConfigが複数あるとき' do
      let(:config) { create(:list_crawl_config, domain: domain, domain_path: "#{domain}/bbb") }
      let(:config2) { create(:list_crawl_config, domain: domain, domain_path: "#{domain}/aaa") }
      let(:request) { create(:request, corporate_list_site_start_url: start_url) }
      let(:start_url) { "https:#{domain}/aaa/bbb/ccc" }

      before do
        config2
        test_class_obj.instance_variable_set(:@req, request)
      end

      it do
        expect(subject).to eq config2
      end
    end
  end
end
