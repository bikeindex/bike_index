require "rails_helper"

RSpec.describe BikebookSchemasController, type: :request do
  describe "show" do
    let(:component_json) { %({\n  "schema_version": "2.0.0",\n  "id": "c/aventon/2024/a100",\n  "type": "ebike-motor"\n}\n) }
    # the test cache is a file store, which an earlier run leaves its answers in, and nothing resets WebMock's count
    before do
      Rails.cache.clear
      WebMock.reset!
    end

    it "answers with a model's, a component's or a classification's file as the repository has it" do
      stubs = {"components/aventon/2024/a100" => component_json, "vehicle_models/segway/2025/gt3-pro" => %({"id": "m/segway/2025/gt3-pro"}),
               "e_vehicle_classifications/us/class-1" => %({"name": "Class 1"})}.map do |path, body|
        WebMock.stub_request(:get, "#{Integrations::Bikebook::RepositoryRecord::URL}#{path}.json").to_return(body:)
      end

      get "/bikebook_schemas/c/aventon/2024/a100"
      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq "application/json"
      expect(response.body).to eq component_json
      get "/bikebook_schemas/m/segway/2025/gt3-pro"
      expect(response.parsed_body).to eq("id" => "m/segway/2025/gt3-pro")
      get "/bikebook_schemas/evc/us/class-1"
      expect(response.parsed_body).to eq("name" => "Class 1")
      # kept, so asking again doesn't ask GitHub
      get "/bikebook_schemas/c/aventon/2024/a100"
      expect(response.body).to eq component_json
      stubs.each { WebMock::API.assert_requested(it, times: 1) }
    end

    it "is not found for an id the repository has no file for, or that isn't a record's" do
      missing = WebMock.stub_request(:get, "#{Integrations::Bikebook::RepositoryRecord::URL}vehicle_models/segway/2025/nope.json")
        .to_return(status: 404)

      2.times { get "/bikebook_schemas/m/segway/2025/nope" }
      expect(response).to have_http_status(:not_found)
      WebMock::API.assert_requested(missing, times: 1)
      get "/bikebook_schemas/aventon/2025"
      expect(response).to have_http_status(:not_found)
      get "/bikebook_schemas/m/../config/secrets"
      expect(response).to have_http_status(:not_found)
    end

    it "is unavailable while GitHub doesn't answer, and asks again next time" do
      down = WebMock.stub_request(:get, "#{Integrations::Bikebook::RepositoryRecord::URL}components/aventon/2024/a100.json")
        .to_return(status: 503)

      2.times { get "/bikebook_schemas/c/aventon/2024/a100" }
      expect(response).to have_http_status(:service_unavailable)
      expect(response.parsed_body).to eq("error" => "The Bike Book repository isn't answering")
      WebMock::API.assert_requested(down, times: 2)
    end
  end
end
