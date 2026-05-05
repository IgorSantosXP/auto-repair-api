module Api
  module V1
    class ReportsController < BaseController
      def metrics
        from = params[:from].present? ? Date.parse(params[:from]) : nil
        to   = params[:to].present?   ? Date.parse(params[:to])   : nil

        data = Reports::Queries::AverageExecutionTimeQuery.call(from: from, to: to)
        render_success(data)
      rescue Date::Error
        render_error(code: "invalid_date", message: "Invalid date format. Use YYYY-MM-DD.", status: :bad_request)
      end
    end
  end
end
