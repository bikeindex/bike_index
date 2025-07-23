# frozen_string_literal: true

require "rails_helper"

RSpec.describe SortableHelper, type: :helper do
  before { controller.params = ActionController::Parameters.new(passed_params) }

  describe "sortable_search_params" do
    context "no sortable_search_params" do
      let(:passed_params) { {party: "stuff"} }
      it "returns an empty hash" do
        expect(sortable_search_params.to_unsafe_h).to eq({})
      end
    end
    context "query items" do
      let(:passed_params) { {query_items: %w[something iiiiii], search_email: "stttt"} }
      it "includes the query items" do
        expect(sortable_search_params.to_unsafe_h).to eq passed_params.as_json
      end
    end
    context "direction, sort" do
      let(:passed_params) { {direction: "asc", sort: "stolen", party: "long"} }
      let(:target) { {direction: "asc", sort: "stolen"} }
      it "returns target hash" do
        expect(sortable_search_params.to_unsafe_h).to eq(target.as_json)
      end
    end
    context "direction, sort, search param" do
      let(:time) { Time.current.to_i }
      let(:passed_params) { {direction: "asc", sort: "stolen", party: "long", search_stuff: "xxx", user_id: 21, organization_id: "xxx", start_time: time, end_time: time, period: "custom", primary_activity: "mtb"} }
      let(:target) { {direction: "asc", sort: "stolen", search_stuff: "xxx", user_id: 21, organization_id: "xxx", start_time: time, end_time: time, period: "custom", primary_activity: "mtb"} }
      it "returns target hash" do
        expect(sortable_search_params.to_unsafe_h).to eq(target.as_json)
      end
    end
    context "direction, sort, period: all " do
      let(:passed_params) { {direction: "asc", sort: "stolen", period: "all"} }
      let(:target) { {direction: "asc", sort: "stolen", period: "all"} }
      it "returns an empty hash" do
        expect(sortable_search_params?).to be_falsey
      end
    end
    context "direction, sort, period: week" do
      let(:passed_params) { {direction: "asc", sort: "stolen", period: "week"} }
      let(:target) { {direction: "asc", sort: "stolen", period: "week"} }
      it "returns an empty hash" do
        expect(sortable_search_params?).to be_truthy
      end
    end
  end

  describe "#sortable" do
    let(:passed_params) { {} }
    let(:sort_column) { "name" }
    let(:sort_direction) { "asc" }

    before { allow_any_instance_of(SortableHelper).to receive(:sortable_url).and_return("/") }

    context "when render_sortable is false" do
      it "returns only the title string when skip_sortable is true" do
        result = sortable("name", "Full Name", skip_sortable: true)
        expect(result).to eq("Full Name")
      end

      it "returns only the title string when render_sortable is explicitly false" do
        result = sortable("name", "Full Name", render_sortable: false)
        expect(result).to eq("Full Name")
      end
    end

    context "when render_sortable is true or default" do
      it "generates a link with sortable class" do
        result = sortable("email")
        expect(result).to match(/class=..?sortable-link/)
        expect(result).to include("Email")
      end

      it "preserves existing CSS classes" do
        result = sortable("name", "Name", class: "existing-class")
        expect(result).to match(/class=..?existing-class sortable-link active/)
      end

      it "includes data attributes and other html options" do
        result = sortable("email", "Email", {data: {turbo: false}, id: "sort-link"})
        expect(result).to include('data-turbo="false"')
        expect(result).to include('id="sort-link"')
      end
    end
  end
end
