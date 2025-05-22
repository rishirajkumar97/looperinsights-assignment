class ShowsController < ApplicationController
  include Renderable
  rescue_from StandardError, with: :render_internal_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  def index
    shows = Show.includes(network: :country, web_channel: :country)
              .page(pagination_params[:page])
              .per(pagination_params[:per_page])

    render json: {
      data: shows.as_json(
        include: {
          network: { include: :country, except: [ :created_at, :updated_at ] },
          web_channel: { include: :country, except: [ :created_at, :updated_at ] }
        },
        except: [ :created_at, :updated_at ]
      ),
      pagination: {
        current_page: shows.current_page,
        next_page: shows.next_page,
        prev_page: shows.prev_page,
        total_pages: shows.total_pages,
        total_count: shows.total_count
      }
    }
  end

  def show
    record = show = Show.includes(network: :country, web_channel: :country).find_by!(id: params[:id])
    render json: {
      data: record.as_json(
        include: {
          network: {
            include: :country,
            except: [ :created_at, :updated_at ]
          },
          web_channel: {
            include: :country,
            except: [ :created_at, :updated_at ]
          }
        },
        except: [ :created_at, :updated_at ]
      )
    }
  end

  def query
    search = Show.ransack(params[:q])
    shows = search.result.includes(network: :country, web_channel: :country).page(pagination_params[:page]).per(pagination_params[:per_page] || 10)

    render json: {
      data: shows.as_json(
        include: {
          network: { include: :country, except: [ :created_at, :updated_at ] },
          web_channel: { include: :country, except: [ :created_at, :updated_at ] }
        },
        except: [ :created_at, :updated_at ]
      ),
      pagination: {
        current_page: shows.current_page,
        next_page: shows.next_page,
        prev_page: shows.prev_page,
        total_pages: shows.total_pages,
        total_count: shows.total_count
      }
    }
  end
end
