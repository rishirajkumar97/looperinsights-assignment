# spec/requests/shows_controller_spec.rb
require 'rails_helper'

RSpec.describe "ShowsController", type: :request do
  describe "GET /shows" do
    before do
      create_list(:show, 3) # Creates 3 shows with associated network and web_channel
    end

    it "returns paginated shows with network and web_channel" do
      get "/shows", params: { page: 1, per_page: 2 }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"].length).to eq(2)
      expect(json["data"].first).to have_key("network")
      expect(json["data"].first).to have_key("web_channel")

      expect(json["pagination"]).to include("current_page", "total_pages", "total_count")
    end
  end

  describe "GET /shows/:id" do
    let(:show) { create(:show) }


    it "returns the specific show with nested data" do
      get "/shows/#{show.id}"
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"]["id"]).to eq(show.id)
      expect(json["data"]).to have_key("network")
      expect(json["data"]).to have_key("web_channel")
    end

    it "returns 404 if show is not found" do
      get "/shows/99999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /shows/query" do
    let!(:matching_show) { create(:show, name: "The Great Adventure") }
    let!(:non_matching_show) { create(:show, name: "Random Show") }

    it "returns filtered shows based on query" do
      get "/shows/query", params: { q: { name_cont: "Great" } }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json["data"].length).to eq(1)
      expect(json["data"].first["name"]).to eq("The Great Adventure")
    end
  end
end
