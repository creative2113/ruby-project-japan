FactoryBot.define do
  factory :result_file do
    path { 'text' }
    status { ResultFile.statuses[:accepted] }
    file_type { ResultFile.file_types[:xlsx] }
    expiration_date { nil }
    fail_files { nil }
    deletable { false }
    start_row { nil }
    end_row { nil }
    parameters { nil }
    phase { nil }
    final { false }
    started_at { nil }

    association :request
  end
end
