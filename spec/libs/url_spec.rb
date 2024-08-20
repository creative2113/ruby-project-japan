require 'rails_helper'

RSpec.describe Url, type: :lib do

  describe 'クラスメソッド exists?' do
    context '指定したURLが存在する場合' do
      it 'URLのページが存在することが確認できて、trueが返ること' do
        expect(described_class.exists?('http://example.com/')).to be_truthy
      end
    end

    context '指定したURLにリダイレクトがかかっている場合' do
      it 'URLのページが存在することが確認できて、trueが返ること' do
        # このURLは5回ぐらいリダイレクトされる
        expect(described_class.exists?('https://www.aaa.com/')).to be_truthy
      end

      it 'URLのページが存在することが確認できて、最終的なドメインが返る' do
        # このURLはロケート先がパスのみのケース
        expect(described_class.exists?('http://www.timeout.jp/')).to be_truthy
      end
    end

    context 'URLのページが存在しない場合' do
      it 'URLのページが存在しないことを確認できて、falseが返ること' do
        expect(described_class.exists?('https://abcdefg/')).to be_falsey
      end
    end
  end

  describe 'クラスメソッド ban_domain?' do
    context 'URL' do
      context '禁止されたドメイン' do
        it 'trueが返ること' do
          expect(described_class.ban_domain?(url: 'http://sample.aa.cn/aa/bb')).to be_truthy
        end
      end

      context '通常ドメイン' do
        it 'falseが返ること' do
          expect(described_class.ban_domain?(url: 'http://sample.aa.jp/aa/bb')).to be_falsey
        end
      end
    end

    context 'ドメイン' do
      context '禁止されたドメイン' do
        it 'trueが返ること' do
          expect(described_class.ban_domain?(domain: 'sample.aa.cn')).to be_truthy
        end
      end

      context '通常ドメイン' do
        it 'falseが返ること' do
          expect(described_class.ban_domain?(domain: 'sample.aa.jp')).to be_falsey
        end
      end
    end
  end

  describe 'クラスメソッド get_final_domain' do
    context '指定したURLが存在する場合' do
      it 'URLのページが存在することが確認できて、ドメインが返ること' do
        expect(described_class.get_final_domain('http://yahoo.co.jp/')).to eq 'www.yahoo.co.jp'
      end
    end

    context '指定したURLにリダイレクトがかかっている場合' do
      it 'URLのページが存在することが確認できて、最終的なドメインが返る' do
        # このURLは5回ぐらいリダイレクトされる
        expect(described_class.get_final_domain('https://aaa.com/')).to eq 'www.aaa.com'
      end

      it 'URLのページが存在することが確認できて、最終的なドメインが返る' do
        # このURLはロケート先がパスのみのケース
        expect(described_class.get_final_domain('http://www.timeout.jp/')).to eq 'www.timeout.jp'
      end
    end

    context 'URLのページが404の場合' do
      it '404が返ること' do
        # このページは404になるページ
        expect(described_class.get_final_domain('https://next.rikunabi.com/asdf')).to eq '404'
      end
    end

    context 'URLのページが存在しない場合' do
      it 'URLのページが存在しないことを確認できて、nilが返ること' do
        expect(described_class.get_final_domain('https://abcdefg/')).to be_nil
      end
    end
  end

  describe 'クラスメソッド get_domain' do
    it 'ドメインの抽出ができること' do
      expect(described_class.get_domain('http://www.example.com/aaa/bbb.html')).to eq 'www.example.com'
    end
  end

  describe '#make_comparing_path' do
    context 'スキーマが違う' do
      it { expect(described_class.make_comparing_path('http://aaa.com', 'ab://aaa.com')).to be_nil }
    end

    context 'ドメインが不一致' do
      it { expect(described_class.make_comparing_path('http://aaa.com', 'http://bbb.com')).to be_nil }
    end

    context 'ドメインが不一致' do
      it { expect(described_class.make_comparing_path('http://aaa.com', 'http://bbb.com')).to be_nil }
    end

    context 'パスのサイズが不一致' do
      it { expect(described_class.make_comparing_path('http://aaa.com/a/b', 'http://aaa.com/a/b/')).to be_nil }
    end

    context '正常系でクエリがあるとき' do
      let(:comaping_path) { described_class.make_comparing_path('https://aaa.com/a/b/c/d?page=5&a=t&c=5&gg=rt', 'http://aaa.com/a/f/g/d?page=6&a=6&b=4&gg=rt') }
      it { expect(comaping_path).to eq ['aaa.com', ['a', described_class::ANYTHING_DIR, described_class::ANYTHING_DIR, 'd'], {'a'=>described_class::ANYTHING_VALUE, 'gg'=>'rt', 'page'=>described_class::ONLY_NUMBER}].to_json }
    end

    context '正常系でクエリがないとき' do
      let(:comaping_path) { described_class.make_comparing_path('https://aaa.com/a/b/c/d/e', 'http://aaa.com/a/f/g/d/f') }
      it { expect(comaping_path).to eq ['aaa.com', ['a', described_class::ANYTHING_DIR, described_class::ANYTHING_DIR, 'd', described_class::ANYTHING_DIR], {}].to_json }
    end

    context '正常系で片方にクエリがないとき' do
      let(:comaping_path) { described_class.make_comparing_path('https://aaa.com/a/b/c/d/e', 'http://aaa.com/a/f/g/d/f?page=5') }
      it { expect(comaping_path).to eq ['aaa.com', ['a', described_class::ANYTHING_DIR, described_class::ANYTHING_DIR, 'd', described_class::ANYTHING_DIR], {}].to_json }
    end
  end

  describe '#match_with_comparing_path?' do
    let(:comaping_path) { ['aaa.com', ['a', described_class::ANYTHING_DIR, 'c', described_class::ANYTHING_DIR], {'a'=>described_class::ANYTHING_VALUE, 'gg'=>'rt', 'page'=>described_class::ONLY_NUMBER}].to_json }

    context 'スキーマがhttpではない' do
      let(:url) { 'aa://aaa.com/a/b/c/d?a=r&gg=rt&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context 'hostが異なる' do
      let(:url) { 'https://aa.com/a/b/c/d?a=r&gg=rt&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context 'pathのサイズが異なる' do
      let(:url) { 'https://aaa.com/a/b/c?a=r&gg=rt&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context 'pathが異なる' do
      let(:url) { 'https://aaa.com/a/b/f/d?a=r&gg=rt&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context 'クエリが異なる。クエリが足りない' do
      let(:url) { 'https://aaa.com/a/b/c/d?gg=rt&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context 'クエリが異なる' do
      let(:url) { 'https://aaa.com/a/b/c/d?a=&gg=b&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context 'クエリが異なる。数字ではない' do
      let(:url) { 'https://aaa.com/a/b/c/d?a=&gg=rt&page=ff' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_falsey }
    end

    context '正常でcomaping_pathのクエリがない' do
      let(:comaping_path) { ['aaa.com', ['a', described_class::ANYTHING_DIR, 'c', described_class::ANYTHING_DIR], {}].to_json }
      let(:url) { 'https://aaa.com/a/b/c/d?a=r&gg=rt&page=3' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_truthy }
    end

    context '正常' do
      let(:url) { 'https://aaa.com/a/b/c/d?a=&gg=rt&page=' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_truthy }
    end

    context '正常' do
      let(:url) { 'https://aaa.com/a/b/c/?a=g&gg=rt&page=4' }
      it { expect(described_class.match_with_comparing_path?(comaping_path, url)).to be_truthy }
    end
  end

  describe '#uniq' do
    before do
      allow(described_class).to receive(:get_final_domain) do |arg, _|
        arg.class == String ? URI.parse(arg).host : arg.host
      end
    end

    context do
      let(:urls) { ['https://aaa.com/aa/bb', 'https://aa1.com/aa/bb', 'http://aaa.com/aa/bb'] }
      it { expect(described_class.uniq(urls)).to eq(['https://aaa.com/aa/bb', 'https://aa1.com/aa/bb'] ) }
    end

    context do
      let(:urls) { ['http://aaa.com:443/aa/bb', 'http://aaa.com:80/aa/bb', 'https://aa1.com/aa/bb'] }
      it { expect(described_class.uniq(urls)).to eq(['http://aaa.com:443/aa/bb', 'https://aa1.com/aa/bb'] ) }
    end

    context do
      let(:urls) { ['https://aa1.com/aa/bb', 'http://aaa.com:443/aa/bb', 'http://aaa.com:80/aa/bb#ss'] }
      it { expect(described_class.uniq(urls)).to eq(['https://aa1.com/aa/bb', 'http://aaa.com:443/aa/bb'] ) }
    end
  end

  describe '#not_exist_page?' do
    context '存在しないURL' do
      let(:url) { 'https://fadfwerwfg23d5gd.com' }
      it { expect(described_class.not_exist_page?(url)).to be_truthy }
    end

    context '存在しないURL' do
      let(:url) { 'http://tyurt23d5gd.com' }
      it { expect(described_class.not_exist_page?(url)).to be_truthy }
    end

    context '存在するURL' do
      let(:url) { 'https://yahoo.co.jp' }
      it { expect(described_class.not_exist_page?(url)).to be_falsey }
    end

    context '存在するURL' do
      let(:url) { 'http://yahoo.co.jp' }
      it { expect(described_class.not_exist_page?(url)).to be_falsey }
    end
  end

  describe '#make_url_from_href' do
    it { expect(described_class.make_url_from_href(href: 'bb/cc', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/ww/bb/cc' }

    it { expect(described_class.make_url_from_href(href: 'bb/cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/ww/zz/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '/bb/cc', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '/bb/cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: './bb/cc', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/ww/bb/cc' }

    it { expect(described_class.make_url_from_href(href: './bb/cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/ww/zz/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '../bb/cc', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '../bb/cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/ww/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '../../bb/cc', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '../../bb/cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '../../bb/cc', curent_url: 'http://aa.com/ww/zz/xx')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '../../bb/cc', curent_url: 'http://aa.com/ww/zz/xx/')).to eq 'http://aa.com/ww/bb/cc' }

    it { expect(described_class.make_url_from_href(href: '././/bb//cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/ww/zz/bb/cc' }

    it { expect(described_class.make_url_from_href(href: './../././bb//cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/ww/bb/cc' }

    it { expect(described_class.make_url_from_href(href: './../././../bb//cc', curent_url: 'http://aa.com/ww/zz/')).to eq 'http://aa.com/bb/cc' }

    it { expect(described_class.make_url_from_href(href: './/bb//cc/../dd/../ee', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/ww/bb/ee' }

    it { expect(described_class.make_url_from_href(href: './/bb//cc//dd/../../../ee', curent_url: 'http://aa.com/ww/zz')).to eq 'http://aa.com/ww/ee' }
  end
end
