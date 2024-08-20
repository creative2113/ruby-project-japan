require 'rails_helper'

RSpec.describe Hash do

  describe '#store_after' do

    it { expect({a: 1, b: 2}.store_after(:c, 3, :a)).to eq ({a: 1, c: 3, b: 2}) }

    it { expect({a: 1, b: 2, c: 3}.store_after(:d, 4, :a)).to eq ({a: 1, d: 4, b: 2, c: 3}) }

    it { expect({a: 1, b: 2, c: 3}.store_after(:d, 4, :b)).to eq ({a: 1, b: 2, d: 4, c: 3}) }

    it { expect({a: 1, b: 2, c: 3}.store_after(:d, 4, :c)).to eq ({a: 1, b: 2, c: 3, d: 4}) }

    it { expect({a: 1, b: 2, c: 3}.store_after(:d, 4, :e)).to eq ({a: 1, b: 2, c: 3, d: 4}) }

    it { expect({a: 1, b: 2, c: 3}.store_after(:a, 4, :b)).to eq ({a: 4, b: 2, c: 3}) }

    it { expect({a: 1, b: 2, c: 3}.store_after(:c, 4, :b)).to eq ({a: 1, b: 2, c: 4}) }
  end
end
