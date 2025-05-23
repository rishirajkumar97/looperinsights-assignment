require 'rails_helper'
require 'webmock/rspec'
RSpec.describe SyncTvMazeDataJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:date_today) { Date.today }
  let(:api_response) do
    [
      {
        "id" => 123,
        "name" => "Sample Episode",
        "airdate" => date_today.to_s
      }
    ]
  end

  before do
    stub_request(:get, /api\.tvmaze\.com\/schedule\?date=.*/).to_return(
      status: 200,
      body: api_response.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )
  end

  context "initial run when RawTvdata is empty" do
    it "fetches data for 91 days, inserts records, and enqueues TransformDataJob" do
      expect(RawTvdata.count).to eq(0)
      expect(TransformDataJob).to receive(:perform_later).with(ids: [123], retry_count: 0)

      expect {
        described_class.perform_now
      }.to change { RawTvdata.count }.by(1)
    end
  end

  context "subsequent run when RawTvdata has data" do
    before { create(:raw_tvdata, id: 120) }

    it "fetches data for the 91st day only and inserts it" do
      expect(TransformDataJob).to receive(:perform_later).with(ids: [123], retry_count: 0)
      expect {
        described_class.perform_now
      }.to change { RawTvdata.count }.by(1)
    end
  end

  # (Include the other tests as provided earlier: API failure, exception, empty response)
end
