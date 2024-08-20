require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe ResultFileWorker, type: :worker do

  let(:reboot_file) { "sidekiq_reboot_for_test_#{Random.alphanumeric}" }
  let(:deploy_file) { "deploy_for_test_#{Random.alphanumeric}" }
  let(:cntl_path) { "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:sidekiq_reboot]}" }
  let(:deploy_cntl_path) { "#{Rails.application.credentials.control_directory[:path]}/#{EasySettings.control_files[:deploying]}" }
  let(:test_log) { "test_log_#{Random.alphanumeric}" }
  let(:test_log_path) { "log/#{test_log}_#{Time.zone.now.strftime("%Y%m%d")}.log" }


  before do
    Sidekiq::Worker.clear_all
    ActionMailer::Base.deliveries.clear

    allow_any_instance_of(Sidekiqer).to receive(:sleep).and_return(nil)
    allow_any_instance_of(ChromeKiller).to receive(:execute).and_return(nil)
    allow(Memory).to receive(:free_and_available).and_return('2000M')
    allow(MyLog).to receive(:new).and_return(MyLog.new(test_log))

    allow(EasySettings.control_files).to receive('[]') do |arg|
      if arg == :sidekiq_reboot
        reboot_file
      elsif arg == :deploying
        deploy_file
      end
    end
  end

  after do
    FileUtils.rm_f(test_log_path)
    FileUtils.rm_f(cntl_path)
    FileUtils.rm_f(deploy_cntl_path)
  end

  describe '#perform' do

    let(:user)   { create(:user) }
    let(:req)    { create(:request, user: user) }
    let(:status) { ResultFile.statuses[:accepted] }
    let(:result_file) { create(:result_file, request: req, status: status, path: nil) }
    let(:file_path) { 'aaa/bb/ccc' }
    let(:fail_files) { nil }



    context '正常系' do

      context 'すでに完了しているとき' do
        let(:status) { ResultFile.statuses[:completed] }

        before do
          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute).and_return(nil)
        end

        it '何も実行しない' do
          Sidekiq::Testing.fake! do
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'completed'
            updated_at = result_file.updated_at
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'completed'
            expect(result_file.updated_at).to eq updated_at
          end
        end
      end

      context 'ループ1回' do

        before do
          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            rf.update(status: ResultFile.statuses[:completed])
          end
        end

        it 'ResultFileのステータスは完了になる' do
          Sidekiq::Testing.fake! do
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'completed'

            log = File.read(test_log_path)
            expect(log).to match(/\[ResultFileWorker\]\[#execute\] START/)
            expect(log).not_to match(/START Sidekiq Reboot/)
            expect(log).not_to match(/Made Reboot Cntl File/)
            expect(log).not_to match(/Remove Stop Cntl File/)
            expect(log).not_to match(/END Sidekiq Reboot/)

             expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end

      context 'ループ4回' do

        before do
          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3')
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              rf.update(status: ResultFile.statuses[:completed])
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it 'ResultFileのステータスは完了になる' do
          Sidekiq::Testing.fake! do
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'completed'
            expect(result_file.phase).to eq 'phase4'

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/TEST EXECUTE phase4/)
            expect(log).not_to match(/START Sidekiq Reboot/)
            expect(log).not_to match(/Made Reboot Cntl File/)
            expect(log).not_to match(/Remove Stop Cntl File/)
            expect(log).not_to match(/END Sidekiq Reboot/)

            expect(ActionMailer::Base.deliveries.size).to eq(0)
          end
        end
      end

      context 'ループ4回 finalの場合' do
        let(:result_file) { create(:result_file, request: req, status: status, path: nil, final: true) }

        before do
          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3')
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              rf.update(status: ResultFile.statuses[:completed])
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it 'ResultFileのステータスは完了になる' do
          Sidekiq::Testing.fake! do
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'completed'
            expect(result_file.phase).to eq 'phase4'

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/TEST EXECUTE phase4/)
            expect(log).not_to match(/START Sidekiq Reboot/)
            expect(log).not_to match(/Made Reboot Cntl File/)
            expect(log).not_to match(/Remove Stop Cntl File/)
            expect(log).not_to match(/END Sidekiq Reboot/)

            expect(ActionMailer::Base.deliveries.size).to eq(1)
            expect(ActionMailer::Base.deliveries[0].to).to eq([user.email, req.mail_address])
            expect(ActionMailer::Base.deliveries[0].subject).to match(/リクエストが完了しました。/)
            expect(ActionMailer::Base.deliveries[0].body).to match(/リクエストが完了しました。/)
          end
        end
      end

      context 'ループ4回 & sidekiq再起動' do

        before do
          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3', parameters: {stop_sidekiq: true}.to_json)
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              rf.update(status: ResultFile.statuses[:completed])
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it 'ResultFileのステータスは完了になる' do
          Sidekiq::Testing.fake! do
            expect(File.exist?(cntl_path)).to be_falsey
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'completed'
            expect(result_file.phase).to eq 'phase4'
            expect(File.exist?(cntl_path)).to be_falsey

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/TEST EXECUTE phase4/)
            expect(log).to match(/START Sidekiq Reboot/)
            expect(log).to match(/Made Reboot Cntl File/)
            expect(log).to match(/Remove Stop Cntl File/)
            expect(log).to match(/END Sidekiq Reboot/)
          end
        end
      end

      context 'ループ4回 & 他のsidekiq再起動が実行中' do

        before do
          FileUtils.touch(cntl_path)

          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3', parameters: {stop_sidekiq: true}.to_json)
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              rf.update(status: ResultFile.statuses[:completed])
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it do
          Sidekiq::Testing.fake! do
            expect(File.exist?(cntl_path)).to be_truthy
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'waiting'
            expect(result_file.phase).to eq 'phase3'
            expect(File.exist?(cntl_path)).to be_truthy

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/Reboot Cntl File Exsisted/)
            expect(log).to match(/Sidekiq Rbbooting 実行中 : rebooting/)
            expect(log).not_to match(/TEST EXECUTE phase4/)
            expect(log).not_to match(/START Sidekiq Reboot/)
            expect(log).not_to match(/Made Reboot Cntl File/)
            expect(log).not_to match(/Remove Stop Cntl File/)
            expect(log).not_to match(/END Sidekiq Reboot/)
          end
        end
      end

      context 'ループ4回 & デプロイが実行中' do

        before do
          FileUtils.touch(deploy_cntl_path)

          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3', parameters: {stop_sidekiq: true}.to_json)
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              rf.update(status: ResultFile.statuses[:completed])
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it do
          Sidekiq::Testing.fake! do
            expect(File.exist?(deploy_cntl_path)).to be_truthy
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'waiting'
            expect(result_file.phase).to eq 'phase3'
            expect(File.exist?(deploy_cntl_path)).to be_truthy

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/デプロイ用のコントロールファイルが存在しています。 Cntl File Exsisted/)
            expect(log).to match(/Sidekiq Rbbooting 実行中 : deploying/)
            expect(log).not_to match(/TEST EXECUTE phase4/)
            expect(log).not_to match(/START Sidekiq Reboot/)
            expect(log).not_to match(/Made Reboot Cntl File/)
            expect(log).not_to match(/Remove Stop Cntl File/)
            expect(log).not_to match(/END Sidekiq Reboot/)
          end
        end
      end

      context 'ループ4回 & Sidekiq再起動でエラー' do

        before do
          allow_any_instance_of(Sidekiqer).to receive(:quiet_request_process!).and_raise(RuntimeError)

          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3', parameters: {stop_sidekiq: true}.to_json)
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              rf.update(status: ResultFile.statuses[:completed])
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it do
          Sidekiq::Testing.fake! do
            expect(File.exist?(cntl_path)).to be_falsey
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'waiting'
            expect(result_file.phase).to eq 'phase3'
            expect(File.exist?(cntl_path)).to be_falsey

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/START Sidekiq Reboot/)
            expect(log).to match(/Made Reboot Cntl File/)
            expect(log).to match(/Error発生/)
            expect(log).to match(/Sidekiq Rbbooting エラー/)
            expect(log).to match(/Remove Stop Cntl File/)
            expect(log).not_to match(/TEST EXECUTE phase4/)
            expect(log).not_to match(/END Sidekiq Reboot/)
          end
        end
      end
    end

    context '異常系' do

      context 'result_file作成した後、step=2, sidekiq再起動してない' do
        before do

          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              raise RuntimeError, 'xxxx error'
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it do
          Sidekiq::Testing.fake! do
            expect(File.exist?(cntl_path)).to be_falsey
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'error'
            expect(result_file.phase).to eq 'phase2'
            expect(File.exist?(cntl_path)).to be_falsey

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/RuntimeError/)
            expect(log).to match(/xxxx error/)
            expect(log).not_to match(/TEST EXECUTE phase3/)
            expect(log).not_to match(/START Sidekiq Reboot/)
            expect(log).to match(/RuntimeError/)
            expect(log).not_to match(/TEST EXECUTE phase4/)
            expect(log).not_to match(/END Sidekiq Reboot/)

            expect(ActionMailer::Base.deliveries.size).to eq(2)
            expect(ActionMailer::Base.deliveries[1].subject).to match(/エクセル作成でエラー発生/)
          end
        end
      end

      context 'ループ4回 & sidekiq再起動後にエラー' do

        before do
          allow_any_instance_of(ResultFileWorker).to receive(:cmd_execute) do |_, rf|
            if rf.reload.phase.blank?
              rf.update(phase: 'phase2')
            elsif rf.phase == 'phase2'
              rf.update(phase: 'phase3', parameters: {stop_sidekiq: true}.to_json)
            elsif rf.phase == 'phase3'
              rf.update(phase: 'phase4')
            elsif rf.phase == 'phase4'
              raise RuntimeError, 'xxxx error'
            end
            MyLog.new(test_log).log "TEST EXECUTE #{rf.phase}"
          end
        end

        it 'ResultFileのステータスは完了になる' do
          Sidekiq::Testing.fake! do
            expect(File.exist?(cntl_path)).to be_falsey
            expect { ResultFileWorker.perform_async(result_file.id) }.to change { ResultFileWorker.jobs.size }.by(1)
            expect(result_file.reload.status).to eq 'accepted'
            ResultFileWorker.drain
            expect(result_file.reload.status).to eq 'error'
            expect(result_file.phase).to eq 'phase4'
            expect(File.exist?(cntl_path)).to be_falsey

            log = File.read(test_log_path)
            expect(log).to match(/TEST EXECUTE phase2/)
            expect(log).to match(/TEST EXECUTE phase3/)
            expect(log).to match(/TEST EXECUTE phase4/)
            expect(log).to match(/START Sidekiq Reboot/)
            expect(log).to match(/Made Reboot Cntl File/)
            expect(log).to match(/Remove Stop Cntl File/)
            expect(log).to match(/END Sidekiq Reboot/)

            expect(ActionMailer::Base.deliveries.size).to eq(4)
            expect(ActionMailer::Base.deliveries[0].subject).to match(/再起動 Sidekiq 開始/)
            expect(ActionMailer::Base.deliveries[2].subject).to match(/エクセル作成でエラー発生/)
            expect(ActionMailer::Base.deliveries[3].subject).to match(/再起動 Sidekiq 終了/)
          end
        end
      end
    end
  end
end
