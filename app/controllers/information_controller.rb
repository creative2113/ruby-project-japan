class InformationController < ApplicationController
  def index
    @notices = Notice.opened
  end

  def specified_commercial_transaction_act
  end
end
