module Paginatable
  extend ActiveSupport::Concern

  DEFAULT_PAGE     = 1
  DEFAULT_PER_PAGE = 10
  MAX_PER_PAGE     = 100

  def pagination_params
    {
      page:      (params[:page].presence || DEFAULT_PAGE).to_i,
      per_page:  [ (params[:per_page].presence || DEFAULT_PER_PAGE).to_i, MAX_PER_PAGE ].min
    }
  end
end
