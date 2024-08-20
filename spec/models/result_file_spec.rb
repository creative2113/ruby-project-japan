require 'rails_helper'

RSpec.describe ResultFile, type: :model do
  describe '#finished' do
    subject { result_file.finished? }
    let(:result_file) { create(:result_file, status: status) }

    context 'statusがaccepted' do
      let(:status) { ResultFile.statuses[:accepted] }
      it { expect(subject).to be_falsey }
    end

    context 'statusがcompleted' do
      let(:status) { ResultFile.statuses[:completed] }
      it { expect(subject).to be_truthy }
    end

    context 'statusがerror' do
      let(:status) { ResultFile.statuses[:error] }
      it { expect(subject).to be_truthy }
    end
  end

  describe '#available_download?' do
    subject { result_file.available_download? }
    let(:result_file) { create(:result_file, expiration_date: expiration_date, status: ResultFile.statuses[:completed]) }

    context 'expiration_dateがblank' do
      let(:expiration_date) { nil }
      it { expect(subject).to be_truthy }
    end

    context 'expiration_dateが本日' do
      let(:expiration_date) { Time.zone.today }
      it { expect(subject).to be_truthy }
    end

    context 'expiration_dateが昨日' do
      let(:expiration_date) { Time.zone.today - 1.day }
      it { expect(subject).to be_falsey }
    end
  end

  describe '#available_request?' do
    subject { result_file.available_request? }
    let(:request) { create(:request, expiration_date: expiration_date) }
    let(:result_file) { create(:result_file, request: request, status: ResultFile.statuses[:completed]) }

    context 'requestのexpiration_dateがblank' do
      let(:expiration_date) { nil }
      it { expect(subject).to be_truthy }
    end

    context 'requestのexpiration_dateが本日' do
      let(:expiration_date) { Time.zone.today }
      it { expect(subject).to be_truthy }
    end

    context 'requestのexpiration_dateが昨日' do
      let(:expiration_date) { Time.zone.today - 1.day }
      it { expect(subject).to be_falsey }
    end
  end

  describe '#set_delete_flag!' do
    subject { ResultFile.set_delete_flag!(request) }
    let(:request) { create(:request) }
    let(:result_file1) { create(:result_file, request: request, deletable: false) }
    let(:result_file2) { create(:result_file, request: request, deletable: false) }
    let(:result_file3) { create(:result_file, request: request, deletable: false) }
    let(:result_file4) { create(:result_file, request: request, deletable: false) }
    let(:result_file5) { create(:result_file, request: request, deletable: false) }
    let(:result_file6) { create(:result_file, request: request, deletable: false) }
    let(:result_file7) { create(:result_file, request: request, deletable: false) }
    let(:result_file8) { create(:result_file, request: request, deletable: false) }
    let(:result_file9) { create(:result_file, request: request, deletable: false) }

    context 'result_fileが9つある時' do
      before do
        result_file1
        result_file2
        result_file3
        result_file4
        result_file5
        result_file6
        result_file7
        result_file8
        result_file9
      end

      it '7つを除いてdeletableがtrueになる' do
        subject
        expect(result_file1.reload.deletable).to be_truthy
        expect(result_file2.reload.deletable).to be_truthy
        expect(result_file3.reload.deletable).to be_falsey
        expect(result_file4.reload.deletable).to be_falsey
        expect(result_file5.reload.deletable).to be_falsey
        expect(result_file6.reload.deletable).to be_falsey
        expect(result_file7.reload.deletable).to be_falsey
        expect(result_file8.reload.deletable).to be_falsey
        expect(result_file9.reload.deletable).to be_falsey
      end
    end

    context 'result_fileが7つある時' do
      before do
        result_file1
        result_file2
        result_file3
        result_file4
        result_file5
        result_file6
        result_file7
      end

      it 'deletableがfalseのまま' do
        subject
        expect(result_file1.reload.deletable).to be_falsey
        expect(result_file2.reload.deletable).to be_falsey
        expect(result_file3.reload.deletable).to be_falsey
        expect(result_file4.reload.deletable).to be_falsey
        expect(result_file5.reload.deletable).to be_falsey
        expect(result_file6.reload.deletable).to be_falsey
        expect(result_file7.reload.deletable).to be_falsey
      end
    end
  end
end
