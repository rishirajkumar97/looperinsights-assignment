require 'rails_helper'

RSpec.describe "EpisodesController", type: :request do
  describe "GET /episodes" do
    let!(:country) { create(:country) }
    let!(:network) { create(:network, country: country) }
    let!(:web_channel) { create(:web_channel, country: country) }

    let!(:high_rated_show) { create(:show, avg_rating: 9.0, network: network, web_channel: web_channel) }
    let!(:low_rated_show)  { create(:show, avg_rating: 3.0, network: network, web_channel: web_channel) }
    let!(:null_rated_show) { create(:show, avg_rating: nil, network: network, web_channel: web_channel) }

    let!(:episode1) { create(:episode, airdate: Date.today, show: high_rated_show) }
    let!(:episode2) { create(:episode, airdate: Date.today, show: low_rated_show) }
    let!(:episode3) { create(:episode, airdate: Date.today, show: null_rated_show) }

    context "basic pagination and sorting by show avg_rating" do
      it "returns top-rated episodes airing today, excluding NULL show ratings" do
        get "/episodes", params: {
          q: {
            airdate_eq: Date.today.to_s,
            show_avg_rating_not_null: 1,
            s: "show_avg_rating desc"
          },
          page: 1,
          per_page: 10
        }, headers: basic_auth_header

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].size).to eq(2)
        expect(body["data"].map { |ep| ep.dig("show", "avg_rating") }).to all(be_present)
        expect(body["data"].first.dig("show", "avg_rating")).to be >= body["data"].last.dig("show", "avg_rating")
      end
    end

    context "no matching episodes" do
      it "returns empty array if no episodes air on a given date" do
        get "/episodes", params: {
          q: {
            airdate_eq: Date.tomorrow.to_s
          },
          page: 1,
          per_page: 10
        }, headers: basic_auth_header

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"]).to eq([])
      end
    end

    context "pagination check" do
      before do
        create_list(:episode, 15, airdate: Date.today, show: high_rated_show)
      end

      it "paginates results correctly" do
        get "/episodes", params: {
          q: {
            airdate_eq: Date.today.to_s,
            show_avg_rating_not_null: 1
          },
          page: 2,
          per_page: 10
        }, headers: basic_auth_header

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body["data"].size).to eq(7) # 15 created + 2 existing (17 total, page 2 has 7)
      end
    end
  end

  describe "GET /episodes/:id" do
    let(:episode) { create(:episode) }

    it "returns the episode with its associated show data" do
      get "/episodes/#{episode.id}", headers: basic_auth_header

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body["data"]["id"]).to eq(episode.id)
      expect(body["data"]["show"]).to be_present
    end

    it "returns 404 for non-existing episode" do
      get "/episodes/999999", headers: basic_auth_header

      expect(response).to have_http_status(:not_found)
    end
  end
end
