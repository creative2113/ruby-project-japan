require 'rails_helper'

RSpec.describe InquiriesController, type: :controller do
  before { create_public_user }

  after { ActionMailer::Base.deliveries.clear }

  describe "GET new" do

    before { get :new }

    it { expect(response.status).to eq(200) }
    it { expect(response).to render_template :new }
  end

  describe "POST create" do
    let(:name)         { 'Tanaka Ken' }
    let(:mail)         { 'sample@example.com' }
    let(:body)         { 'aaaaa' }
    let(:params)       { {inquiry: {name: name, mail: mail, body: body } } }
    let(:inquiry)      { Inquiry.last }
    let(:from_address) { 'notifications@corp-list-pro.com' }

    before { create(:ban_condition, mail: 'ban_mail@example.com', ban_action: BanCondition.ban_actions['inquiry']) }

    context '必須項目が未入力の場合' do
      before { post :create, params: params }

      context '名前が未入力の場合' do
        let(:name)   { '' }

        it '登録されずに返ること' do
          expect(assigns(:finish_status)).to eq :need_mandatory_fields
          expect(response.status).to eq(400)
          expect(response).to render_template :new
        end

        it { expect{ post :create, params: params }.to change(Inquiry, :count).by(0) }
      end

      context 'メールアドレスが未入力の場合' do
        let(:mail)   { '' }

        it '登録されずに返ること' do
          expect(assigns(:finish_status)).to eq :need_mandatory_fields
          expect(response.status).to eq(400)
          expect(response).to render_template :new
        end

        it { expect{ post :create, params: params }.to change(Inquiry, :count).by(0) }
      end

      context '問い合わせ内容が未入力の場合' do
        let(:body)   { '' }

        it '登録されずに返ること' do
          expect(assigns(:finish_status)).to eq :need_mandatory_fields
          expect(response.status).to eq(400)
          expect(response).to render_template :new
        end

        it { expect{ post :create, params: params }.to change(Inquiry, :count).by(0) }
      end
    end

    context '名前が30文字超える場合' do
      let(:name) { 'a'*31 }

      it '登録されずに返ること' do
        post :create, params: params

        expect(assigns(:finish_status)).to eq :invalid_name
        expect(response.status).to eq(400)
        expect(response).to render_template :new
      end

      it { expect{ post :create, params: params }.to change(Inquiry, :count).by(0) }
    end

    context 'メールアドレスが間違っている場合' do
      let(:mail) { 'aaaa' }

      it '登録されずに返ること' do
        post :create, params: params

        expect(assigns(:finish_status)).to eq :invalid_email_address
        expect(response.status).to eq(400)
        expect(response).to render_template :new
      end

      it { expect{ post :create, params: params }.to change(Inquiry, :count).by(0) }
    end

    context '禁止されているメールアドレスの場合' do
      let(:mail) { 'aaaa@example.com' }
      before { create(:ban_condition, mail: mail, ban_action: BanCondition.ban_actions['inquiry']) }

      it '登録されずに返ること' do
        post :create, params: params

        expect(response.status).to eq(302)
        expect(response.location).to redirect_to inquiry_path

        expect(ActionMailer::Base.deliveries.size).to eq(1)
        expect(ActionMailer::Base.deliveries[0].subject).to match(/変なお問合せがありました。/)
      end

      it { expect{ post :create, params: params }.to change(Inquiry, :count).by(0) }
    end

    context '正常に受け付けた場合' do

      context 'パブリックユーザの場合' do

        it '登録されること、メールが飛ぶこと' do
          post :create, params: params

          expect(response.status).to eq(302)
          expect(response.location).to redirect_to inquiry_path

          expect(inquiry.reload.name).to eq name
          expect(inquiry.reload.mail).to eq mail
          expect(inquiry.reload.body).to eq body
          expect(inquiry.reload.user_id).to eq User.public_id

          # メールのチェック
          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].to).to eq([mail])
          expect(ActionMailer::Base.deliveries[0].from).to eq([from_address])
          expect(ActionMailer::Base.deliveries[0].subject).to match(/お問い合わせを受け付けました。【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[0].body.parts[0].header['Content-Type'].unparsed_value).to eq 'text/plain'
          expect(ActionMailer::Base.deliveries[0].body.parts[0].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[0].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[0].body.raw_source).to match(/#{body}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[1].header['Content-Type'].unparsed_value).to eq 'text/html'
          expect(ActionMailer::Base.deliveries[0].body.parts[1].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[1].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[1].body.raw_source).to match(/#{body}/)

          expect(ActionMailer::Base.deliveries[1].to).to eq([Rails.application.credentials.mailer[:address]])
          expect(ActionMailer::Base.deliveries[1].from).to eq([Rails.application.credentials.mailer[:address]])
          expect(ActionMailer::Base.deliveries[1].subject).to match(/お問い合わせが届きました。【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].header['Content-Type'].unparsed_value).to eq 'text/plain'
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/件名: お問い合わせ内容につきまして　【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/#{body}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].header['Content-Type'].unparsed_value).to eq 'text/html'
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/件名: お問い合わせ内容につきまして　【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/#{body}/)
        end

        it { expect{ post :create, params: params }.to change(Inquiry, :count).by(1) }
      end

      context 'プランユーザの場合' do
        let(:user) { create(:user) }

        it '登録されること、メールが飛ぶこと' do
          sign_in user

          post :create, params: params

          expect(response.status).to eq(302)
          expect(response.location).to redirect_to inquiry_path


          expect(inquiry.reload.name).to eq name
          expect(inquiry.reload.mail).to eq mail
          expect(inquiry.reload.body).to eq body
          expect(inquiry.reload.user_id).to eq user.id

          # メールのチェック
          expect(ActionMailer::Base.deliveries.size).to eq(2)
          expect(ActionMailer::Base.deliveries[0].to).to eq([mail])
          expect(ActionMailer::Base.deliveries[0].from).to eq([from_address])
          expect(ActionMailer::Base.deliveries[0].subject).to match(/お問い合わせを受け付けました。【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[0].body.parts[0].header['Content-Type'].unparsed_value).to eq 'text/plain'
          expect(ActionMailer::Base.deliveries[0].body.parts[0].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[0].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[0].body.raw_source).to match(/#{body}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[1].header['Content-Type'].unparsed_value).to eq 'text/html'
          expect(ActionMailer::Base.deliveries[0].body.parts[1].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[1].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[0].body.parts[1].body.raw_source).to match(/#{body}/)

          expect(ActionMailer::Base.deliveries[1].to).to eq([Rails.application.credentials.mailer[:address]])
          expect(ActionMailer::Base.deliveries[1].from).to eq([Rails.application.credentials.mailer[:address]])
          expect(ActionMailer::Base.deliveries[1].subject).to match(/お問い合わせが届きました。【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].header['Content-Type'].unparsed_value).to eq 'text/plain'
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/件名: お問い合わせ内容につきまして　【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[0].body.raw_source).to match(/#{body}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].header['Content-Type'].unparsed_value).to eq 'text/html'
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/質問者名: #{name}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/件名: お問い合わせ内容につきまして　【質問番号: #{inquiry.id}】/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/質問番号: #{inquiry.id}/)
          expect(ActionMailer::Base.deliveries[1].body.parts[1].body.raw_source).to match(/#{body}/)
        end

        it { expect{ post :create, params: params }.to change(Inquiry, :count).by(1) }
      end
    end
  end
end
