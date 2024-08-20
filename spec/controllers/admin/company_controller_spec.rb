require 'rails_helper'

RSpec.describe Admin::CompaniesController, type: :controller do

  describe 'POST import_company_file' do

    after { ActionMailer::Base.deliveries.clear }

    subject { post :import_company_file, params: params }
    let(:params) { { companies_file: file_params } }

    let_it_be(:company_group1) { create(:company_group, id: 1, title: '1', grouping_number: 1) }
    let_it_be(:company_group2) { create(:company_group, id: 2, title: '2', grouping_number: 2) }
    let_it_be(:region) { Region.create(name: '関東') }
    let_it_be(:prefecture) { Prefecture.create(name: '東京都') }
    let_it_be(:area_connector1) { AreaConnector.create(region: region, prefecture: nil, city: nil) }
    let_it_be(:area_connector2) { AreaConnector.create(region: region, prefecture: prefecture, city: nil) }

    context '一般ユーザの場合' do
      let_it_be(:user) { create(:user) }

      context 'ファイルを渡していないとき' do
        let(:file_params) { nil }

        it 'インポートが失敗すること' do
          subject
          expect(response.status).to eq 404
        end

        it { expect{ subject }.to change(Company, :count).by(0) }
        it { expect{ subject }.to change(LargeCategory, :count).by(0) }
        it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
        it { expect{ subject }.to change(SmallCategory, :count).by(0) }
        it { expect{ subject }.to change(CategoryConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(0) }
        it { expect{ subject }.to change(City, :count).by(0) }
        it { expect{ subject }.to change(AreaConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyAreaConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(0) }
      end
    end

    context '管理者ユーザの場合' do
      let_it_be(:user) { create(:admin_user) }
      let_it_be(:allow_ip) { create(:allow_ip, :admin) }

      before do
        sign_in user
      end

      context 'ファイルを渡していないとき' do
        let(:file_params) { nil }

        it 'インポートが失敗すること' do
          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to admin_companies_path
          expect(flash[:alert]).to eq 'ファイルが存在しません。'
        end

        it { expect{ subject }.to change(Company, :count).by(0) }
        it { expect{ subject }.to change(LargeCategory, :count).by(0) }
        it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
        it { expect{ subject }.to change(SmallCategory, :count).by(0) }
        it { expect{ subject }.to change(CategoryConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(0) }
        it { expect{ subject }.to change(City, :count).by(0) }
        it { expect{ subject }.to change(AreaConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyAreaConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(0) }
      end

      context '失敗するファイルを渡したとき' do
        let(:file_name) { 'wrong_region.xlsx' }
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', file_name).to_s }
        let(:file_params) { fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

        subject { post :import_company_file, params: params }

        it 'インポートが失敗すること' do
          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to admin_companies_path
          expect(flash[:alert]).to match /インポートに失敗しました/
        end

        it { expect{ subject }.to change(Company, :count).by(0) }
        it { expect{ subject }.to change(LargeCategory, :count).by(0) }
        it { expect{ subject }.to change(MiddleCategory, :count).by(0) }
        it { expect{ subject }.to change(SmallCategory, :count).by(0) }
        it { expect{ subject }.to change(CategoryConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(0) }
        it { expect{ subject }.to change(City, :count).by(0) }
        it { expect{ subject }.to change(AreaConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyAreaConnector, :count).by(0) }
        it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(0) }

        it 'メールが飛ぶこと' do
          subject
          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/#{file_name}/)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/企業インポートに失敗しました。/)
          expect(ActionMailer::Base.deliveries[0].body).to match(/企業インポートに失敗しました。/)
          expect(ActionMailer::Base.deliveries[0].body).to match(/#{file_name}/)
        end
      end

      context 'ファイルを渡したとき' do
        let(:file_name) { 'correct.xlsx' }
        let(:file_path) { Rails.root.join('spec', 'fixtures', 'company_import', file_name).to_s }
        let(:file_params) { fixture_file_upload(file_path, 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet') }

        subject { post :import_company_file, params: params }

        it '正常にインポートが成功すること' do
          subject

          expect(response.status).to eq 302
          expect(response.location).to redirect_to admin_companies_path
          expect(flash[:notice]).to eq 'インポートが成功しました'
          expect(flash[:alert]).to be_nil
        end

        it { expect{ subject }.to change(Company, :count).by(1) }
        it { expect{ subject }.to change(LargeCategory, :count).by(1) }
        it { expect{ subject }.to change(MiddleCategory, :count).by(1) }
        it { expect{ subject }.to change(SmallCategory, :count).by(1) }
        it { expect{ subject }.to change(CategoryConnector, :count).by(3) }
        it { expect{ subject }.to change(CompanyCategoryConnector, :count).by(1) }
        it { expect{ subject }.to change(City, :count).by(1) }
        it { expect{ subject }.to change(AreaConnector, :count).by(1) }
        it { expect{ subject }.to change(CompanyAreaConnector, :count).by(1) }
        it { expect{ subject }.to change(CompanyCompanyGroup, :count).by(2) }

        it 'メールが飛ぶこと' do
          subject
          expect(ActionMailer::Base.deliveries.size).to eq(1)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/#{file_name}/)
          expect(ActionMailer::Base.deliveries[0].subject).to match(/企業インポートに成功しました。/)
          expect(ActionMailer::Base.deliveries[0].body).to match(/企業インポートに成功しました。/)
          expect(ActionMailer::Base.deliveries[0].body).to match(/#{file_name}/)
        end
      end
    end
  end
end
