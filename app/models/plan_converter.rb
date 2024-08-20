class PlanConverter
  class << self
    def convert_to_plan(plan_num)
      if Rails.env.production?
        convert_to_plan_for_production(plan_num)
      else
        convert_to_plan_for_others(plan_num)
      end
    end

    def convert_to_sym(plan_name)
      if Rails.env.production?
        convert_to_sym_for_production(plan_name)
      else
        convert_to_sym_for_others(plan_name)
      end
    end

    private

    def convert_to_plan_for_production(plan_num)
      case EasySettings.plan.invert[plan_num]
      when 'beta_standard'
        MasterBillingPlan.enabled.find_by_name('β版スタンダードプラン')
      when 'beta_gold'
        MasterBillingPlan.enabled.find_by_name('β版ゴールドプラン')
      when 'beta_platinum'
        MasterBillingPlan.enabled.find_by_name('β版プラチナムプラン')
      else
        nil
      end
    end

    def convert_to_plan_for_others(plan_num)
      case EasySettings.plan.invert[plan_num]
      when 'standard'
        MasterBillingPlan.enabled.find_by_name('スタンダードプラン')
      when 'gold'
        MasterBillingPlan.enabled.find_by_name('ゴールドプラン')
      when 'platinum'
        MasterBillingPlan.enabled.find_by_name('プラチナムプラン')
      when 'annually_standard'
        MasterBillingPlan.enabled.find_by_name('年間契約スタンダードプラン')
      when 'annually_gold'
        MasterBillingPlan.enabled.find_by_name('年間契約ゴールドプラン')
      when 'annually_platinum'
        MasterBillingPlan.enabled.find_by_name('年間契約プラチナムプラン')
      when 'beta_standard'
        MasterBillingPlan.enabled.find_by_name('β版スタンダードプラン')
      when 'beta_gold'
        MasterBillingPlan.enabled.find_by_name('β版ゴールドプラン')
      when 'beta_platinum'
        MasterBillingPlan.enabled.find_by_name('β版プラチナムプラン')
      when 'test_light'
        MasterBillingPlan.enabled.find_by_name('Rspecテスト ライトプラン')
      when 'test_standard'
        MasterBillingPlan.enabled.find_by_name('Rspecテスト スタンダードプラン')
      when 'test_annually_light'
        MasterBillingPlan.enabled.find_by_name('Rspecテスト 年間契約ライトプラン')
      when 'test_annually_standard'
        MasterBillingPlan.enabled.find_by_name('Rspecテスト 年間契約スタンダードプラン')
      when 'testerA'
        MasterBillingPlan.enabled.find_by_name('Test TesterA プラン')
      when 'testerB'
        MasterBillingPlan.enabled.find_by_name('Test TesterB プラン')
      when 'testerC'
        MasterBillingPlan.enabled.find_by_name('Test TesterC プラン')
      when 'testerD'
        MasterBillingPlan.enabled.find_by_name('Test TesterD プラン')
      else
        nil
      end
    end

    def convert_to_sym_for_production(plan_name)
      case plan_name
      when 'β版スタンダードプラン'
        :beta_standard
      when 'β版ゴールドプラン'
        :beta_gold
      when 'β版プラチナムプラン'
        :beta_platinum
      else
        nil
      end
    end

    def convert_to_sym_for_others(plan_name)
      case plan_name
      when 'スタンダードプラン'
        :standard
      when 'ゴールドプラン'
        :gold
      when 'プラチナムプラン'
        :platinum
      when '年間契約スタンダードプラン'
        :annually_standard
      when '年間契約ゴールドプラン'
        :annually_gold
      when '年間契約プラチナムプラン'
        :annually_platinum
      when 'β版スタンダードプラン'
        :beta_standard
      when 'β版ゴールドプラン'
        :beta_gold
      when 'β版プラチナムプラン'
        :beta_platinum
      when 'Rspecテスト ライトプラン'
        :test_light
      when 'Rspecテスト スタンダードプラン'
        :test_standard
      when 'Rspecテスト 年間契約ライトプラン'
        :test_annually_light
      when 'Rspecテスト 年間契約スタンダードプラン'
        :test_annually_standard
      when 'Test TesterA プラン'
        :testerA
      when 'Test TesterB プラン'
        :testerB
      when 'Test TesterC プラン'
        :testerC
      when 'Test TesterD プラン'
        :testerD
      else
        nil
      end
    end
  end
end
