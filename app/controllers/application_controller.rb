class ApplicationController < ActionController::API
  private

  def render_success(data, status: :ok)
    render json: data, status: status
  end

  def render_created(data)
    render json: data, status: :created
  end

  def render_no_content
    head :no_content
  end

  def render_error(code:, message:, details: nil, status: :unprocessable_entity)
    render json: { error: { code: code, message: message, details: details }.compact }, status: status
  end

  def render_result(result, on_success: :ok)
    if result.success?
      if on_success == :no_content
        render_no_content
      elsif on_success == :created
        render_created(result.payload)
      else
        render_success(result.payload, status: on_success)
      end
    else
      render_error(
        code: "validation_error",
        message: "Validation failed",
        details: result.errors,
        status: :unprocessable_entity
      )
    end
  end

  def pagination_params
    page     = [params[:page].to_i, 1].max
    per_page = params[:per_page].to_i
    per_page = 25  if per_page < 1
    per_page = 100 if per_page > 100
    { page: page, per_page: per_page }
  end

  def set_pagination_headers(total, page, per_page)
    response.set_header("X-Total-Count", total.to_s)
    response.set_header("X-Page", page.to_s)
    response.set_header("X-Per-Page", per_page.to_s)
  end
end
