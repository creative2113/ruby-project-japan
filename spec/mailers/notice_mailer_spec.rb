require "rails_helper"

RSpec.describe NoticeMailer, type: :mailer do
  before { create_public_user }
  let(:from_address)    { 'notifications@corp-list-pro.com' }
  let(:accept_id)       { 'abcdef' }
  let(:title)           { 'テスト案件 ' }
  let(:file_name)       { 'sample.csv' }
  let(:created_at)      { '2019-02-10 20:46:03 +0900' }
  let(:created_at_char) { '2019年02月10日 20:46:03' }
  let(:request)         { create(:request, accept_id: accept_id, title: title, file_name: file_name,
                                           created_at: created_at, user: user) }

  context 'Public User' do
    let(:user) { User.get_public }

    describe "accept_requeste_mail" do
      let(:mail) { NoticeMailer.accept_requeste_mail(request) }

      it "renders the headers" do
        expect(mail.subject).to eq("リクエストを受け付けました。")
        expect(mail.to).to eq(["to@example.org"])
        expect(mail.from).to eq([from_address])
      end

      it "renders the body" do
        expect(mail.body.encoded).to match(/受付ID: #{accept_id}/)
        expect(mail.body.encoded).to match(/#{title}/)
        expect(mail.body.encoded).to match(/#{confirm_url(accept_id: accept_id).gsub('?','\\?')}/)
        expect(mail.body.encoded).to match(/#{created_at_char}/)
      end
    end

    describe "request_complete_mail" do
      let(:mail) { NoticeMailer.request_complete_mail(request) }

      it "renders the headers" do
        expect(mail.subject).to eq("リクエストが完了しました。")
        expect(mail.to).to eq(["to@example.org"])
        expect(mail.from).to eq([from_address])
      end

      it "renders the body" do
        expect(mail.body.encoded).to match(/受付ID: #{accept_id}/)
        expect(mail.body.encoded).to match(/#{title}/)
        expect(mail.body.encoded).to match(/#{confirm_url(accept_id: accept_id).gsub('?','\\?')}/)
        expect(mail.body.encoded).to match(/#{created_at_char}/)
      end
    end
  end

  context 'Plan User' do
    let(:email) { 'sample@test.com' }
    let(:user)  { create(:user, email: email) }

    describe 'accept_requeste_mail_for_user' do
      let(:mail) { NoticeMailer.accept_requeste_mail_for_user(request) }

      it 'renders the headers' do
        expect(mail.subject).to eq("リクエストを受け付けました。")
        expect(mail.to).to eq([email, 'to@example.org'])
        expect(mail.from).to eq([from_address])
      end

      it 'renders the body' do
        expect(mail.body.encoded).not_to match(/受付ID: #{accept_id}/)
        expect(mail.body.encoded).to match(/#{title}/)
        expect(mail.body.encoded).to match(/#{confirm_url(accept_id: accept_id).gsub('?','\\?')}/)
        expect(mail.body.encoded).to match(/#{created_at_char}/)
      end
    end

    describe 'request_complete_mail_for_user' do
      let(:mail) { NoticeMailer.request_complete_mail_for_user(request) }

      it "renders the headers" do
        expect(mail.subject).to eq("リクエストが完了しました。")
        expect(mail.to).to eq([email, 'to@example.org'])
        expect(mail.from).to eq([from_address])
      end

      it 'renders the body' do
        expect(mail.body.encoded).not_to match(/受付ID: #{accept_id}/)
        expect(mail.body.encoded).to match(/#{title}/)
        expect(mail.body.encoded).to match(/#{confirm_url(accept_id: accept_id).gsub('?','\\?')}/)
        expect(mail.body.encoded).to match(/#{created_at_char}/)
      end
    end
  end

  context 'アラートメール' do
    let(:content) { 'abcdef' }
    let(:mail) { NoticeMailer.notice_emergency_fatal(content, level) }

    describe 'notice_emergency_fatal, :error' do
      let(:level)   { :error }

      it "renders the headers" do
        expect(mail.subject).to eq("エラー発生　要対応")
        expect(mail.to).to eq([Rails.application.credentials.error_email_address])
        expect(mail.from).to eq([from_address])
      end

      it 'renders the body' do
        expect(mail.body.encoded).to match(/#{content}/)
      end
    end

    describe 'notice_emergency_fatal, :fatal' do
      let(:level)   { :fatal }

      it "renders the headers" do
        expect(mail.subject).to eq("エラー発生　要緊急対応")
        expect(mail.to).to eq([Rails.application.credentials.error_email_address])
        expect(mail.from).to eq([from_address])
      end

      it 'renders the body' do
        expect(mail.body.encoded).to match(/#{content}/)
      end
    end
  end

  context 'お問い合わせメール' do
    let(:inquiry) { create(:inquiry) }

    describe '受付メール accepted_inquiry' do
      let(:mail) { NoticeMailer.accepted_inquiry(inquiry) }

      it "renders the headers" do
        expect(mail.subject).to eq("お問い合わせを受け付けました。【質問番号: #{inquiry.id}】")
        expect(mail.to).to eq([inquiry.mail])
        expect(mail.from).to eq([from_address])
      end

      it 'renders the text body' do
        expect(mail.body.parts[0].header['Content-Type'].unparsed_value).to eq 'text/plain'
        expect(mail.body.parts[0].body).to match(/#{inquiry.name} 様/)
        expect(mail.body.parts[0].body).to match(/質問者名: #{inquiry.name}/)
        expect(mail.body.parts[0].body).to match(/質問番号: #{inquiry.id}/)
        expect(mail.body.parts[0].body).to match(/問い合わせ内容:/)
        expect(mail.body.parts[0].body).to match(/#{inquiry.body}/)
      end

      it 'renders the html body' do
        expect(mail.body.parts[1].header['Content-Type'].unparsed_value).to eq 'text/html'
        expect(mail.body.parts[1].body).to match(/#{inquiry.name} 様/)
        expect(mail.body.parts[1].body).to match(/質問者名: #{inquiry.name}/)
        expect(mail.body.parts[1].body).to match(/質問番号: #{inquiry.id}/)
        expect(mail.body.parts[1].body).to match(/問い合わせ内容:/)
        expect(mail.body.parts[1].body).to match(/#{inquiry.body}/)
      end
    end

    describe 'お知らせメール received_inquiry' do
      let(:mail) { NoticeMailer.received_inquiry(inquiry) }

      it "renders the headers" do
        expect(mail.subject).to eq("お問い合わせが届きました。【質問番号: #{inquiry.id}】")
        expect(mail.to).to eq([Rails.application.credentials.mailer[:address]])
        expect(mail.from).to eq([Rails.application.credentials.mailer[:address]])
      end

      it 'renders the text body' do
        expect(mail.body.parts[0].header['Content-Type'].unparsed_value).to eq 'text/plain'
        expect(mail.body.parts[0].body).to match(/質問者名: #{inquiry.name}/)
        expect(mail.body.parts[0].body).to match(/件名: お問い合わせ内容につきまして　【質問番号: #{inquiry.id}】/)
        expect(mail.body.parts[0].body).to match(/質問番号: #{inquiry.id}/)
        expect(mail.body.parts[0].body).to match(/問い合わせ内容:/)
        expect(mail.body.parts[0].body).to match(/#{inquiry.body}/)
      end

      it 'renders the html body' do
        expect(mail.body.parts[1].header['Content-Type'].unparsed_value).to eq 'text/html'
        expect(mail.body.parts[1].body).to match(/質問者名: #{inquiry.name}/)
        expect(mail.body.parts[1].body).to match(/件名: お問い合わせ内容につきまして　【質問番号: #{inquiry.id}】/)
        expect(mail.body.parts[1].body).to match(/質問番号: #{inquiry.id}/)
        expect(mail.body.parts[1].body).to match(/問い合わせ内容:/)
        expect(mail.body.parts[1].body).to match(/#{inquiry.body}/)
      end
    end
  end
end
