class CompanyController < ApplicationController
  def find_areas_categories
    categories = CategoryConnector.find_all_category_comb
    areas   = AreaConnector.find_all_area_comb
    capital_ranges = CompanyGroup.range_combs(CompanyGroup::CAPITAL)
    employee_ranges = CompanyGroup.range_combs(CompanyGroup::EMPLOYEE)
    sales_ranges = CompanyGroup.range_combs(CompanyGroup::SALES)
    count = Company.count

    render json: { status: 200, areas: areas, categories: categories,
                   capital_ranges: capital_ranges, employee_ranges: employee_ranges, sales_ranges: sales_ranges, categories_count: count }

  rescue => e

    logging('error', request, { err_msg: e.message, backtrace: e.backtrace })

    render json: { status: 500, message: 'エラー発生。企業DBから値を取得できませんでした。' }, status: 500
  end

  def count_companies
    not_own_capitals = params['not_own_capitals'] == 'true'
    count = if params['areas_connector_id'].blank? && params['categories_connector_id'].blank? &&
               params['capitals_id'].blank? && params['employees_id'].blank? && params['sales_id'].blank?
      Company.count
    else
      Company.select_by_connectors(params['areas_connector_id'], params['categories_connector_id'],
                                   params['capitals_id'], params['employees_id'], params['sales_id'], not_own_capitals).pluck(:id).uniq.size
    end

    render json: { status: 200, categories_count: count }

  rescue => e

    logging('error', request, { err_msg: e.message, backtrace: e.backtrace })

    render json: { status: 500, message: 'エラー発生。企業数を取得できませんでした。' }, status: 500
  end
end
