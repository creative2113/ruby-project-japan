require 'rails_helper'

RSpec.describe Array do

  describe '#sorting_add' do

    it { expect([0,2,2,4,7,8,11].sorting_add([1,2,3,2,5,6,8,9,10])).to eq ([1, 0, 2, 3, 2, 5, 6, 4, 7, 8, 9, 10, 11]) }

    it { expect([0,1].sorting_add([0,2])).to eq ([0, 2, 1]) }

    it { expect([0,1,2,3].sorting_add([0,2,1,3])).to eq ([0, 2, 1, 3]) }

    it { expect([0,4,3,1,2].sorting_add([0,1,2,3,4])).to eq ([0, 1, 2, 3, 4]) }

    it { expect([0,1,2].sorting_add([0,2,3])).to eq ([0, 1, 2, 3]) }

    it { expect([0,2,3].sorting_add([0,1,2])).to eq ([0, 1, 2, 3]) }

    it { expect([0,1].sorting_add([0,1,2,3])).to eq ([0, 1, 2, 3]) }

    it { expect([0,1,2,3].sorting_add([0,1])).to eq ([0, 1, 2, 3]) }
  end
end
