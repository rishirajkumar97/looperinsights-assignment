class EpisodesController < ApplicationController
  include Renderable

  def index
    q = Episode.ransack(params[:q])
    episodes = q.result
                .includes(show: [ { network: :country }, { web_channel: :country } ])
                .page(pagination_params[:page])
                .per(pagination_params[:per_page])

    render json: {
      data: episodes.as_json(
        include: {
          show: {
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
          }
        },
        except: [ :created_at, :updated_at ]
      ),
      pagination: {
        current_page: episodes.current_page,
        next_page: episodes.next_page,
        prev_page: episodes.prev_page,
        total_pages: episodes.total_pages,
        total_count: episodes.total_count
      }
    }
  end

  def show
    record = Episode.includes(
      show: [ { network: :country }, { web_channel: :country } ]
    ).find_by!(id: params[:id])
    render json: {
      data: record.as_json(
        include: {
          show: {
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
          }
        },
        except: [ :created_at, :updated_at ]
      )
    }
  end
end
