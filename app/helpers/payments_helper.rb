module PaymentsHelper
  def plans_list
    Billing.plan_list.map do |plan|
      n = EasySettings.plan[plan]
      plan_obj = PlanConverter.convert_to_plan(n)
      [plan_obj.select_box_name, n]
    end
    # MasterBillingPlan.enabled.map { |plan| ["#{plan.name}(#{plan.id}) #{plan.price.to_s(:delimited)}円", plan.id] }
  end

  def display_payment_status(billing)
    if billing.current_plans.blank? && billing.next_enable_plan.present?
      '有効化待ち'
    elsif billing.current_plans.blank?
      '未課金'
    elsif billing.current_plans.present? && billing.current_plans[0].trial? && billing.current_plans[0].end_at.present?
      'お試し利用中、停止リクエスト済み'
    elsif billing.current_plans.present? && billing.current_plans[0].trial?
      'お試し利用中'
    elsif billing.user.scheduled_stop?
      'お支払い済み、課金停止済み'
    elsif billing.current_plans.present?
      'お支払い済み'
    end
  end
end
