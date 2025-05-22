module Renderable
  extend ActiveSupport::Concern
  included do
    rescue_from StandardError, with: :render_internal_error
    rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  end

  def render_not_found(exception = nil)
    render json: {
      error: "Resource not found",
      message: exception&.message
    }, status: :not_found
  end

  def render_internal_error(exception = nil)
    Rails.logger.error(exception.message)
    Rails.logger.error(exception.backtrace.join("\n")) if exception
    render json: {
      error: "Internal Server Error",
      message: exception&.message || "Something went wrong"
    }, status: :internal_server_error
  end
end
