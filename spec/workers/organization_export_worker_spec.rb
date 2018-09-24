require "spec_helper"

describe OrganizationExportWorker do
  let(:subject) { OrganizationExportWorker }
  let(:instance) { subject.new }
  let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil) }
  let(:organization) { export.organization }
  let(:black) { FactoryGirl.create(:color, name: "Black") } # Because we use it as a default color
  let(:trek) { FactoryGirl.create(:manufacturer, name: "Trek") }
  let(:bike) { FactoryGirl.create(:creation_organization_bike, manufacturer: trek, primary_frame_color: black, organization: organization) }
  let(:basic_values) do
    [
      "http://test.host/bikes/#{bike.id}",
      bike.created_at.utc,
      "Trek",
      nil,
      "Black",
      bike.serial_number,
      false
    ]
  end
  let(:csv_string) { csv_lines.map { |r| instance.comma_wrapped_string(r) }.join }

  describe "perform" do
    context "bulk import already processed" do
      let(:export) { FactoryGirl.create(:export, progress: "finished") }
      it "returns true" do
        expect(instance).to_not receive(:create_csv)
        instance.perform(export.id)
      end
    end
    context "default" do
      let(:csv_lines) { [export.headers, basic_values] }
      it "does the thing we expect" do
        expect(bike.organizations.pluck(:id)).to eq([organization.id])
        expect(export.file.present?).to be_falsey
        instance.perform(export.id)
        export.reload
        expect(export.progress).to eq "finished"
        expect(export.open_file).to eq(csv_string)
        expect(export.rows).to eq 1
      end
    end

    # Setting up what we have, rather than waiting on everything
    # Maybe will finish this before shipping
    # context "all header options" do
    #   let(:export) { FactoryGirl.create(:export_organization, progress: "pending", file: nil, options: { headers: Export::PERMITTED_HEADERS }) }
    #   let(:fancy_bike) - bike with ownership, multiple colors, manufacturer other
    #   let(:csv_lines) { [export.headers, basic_bike_values, fancy_bike_values] }
    #   it "does the thing we expect" do
    #     expect(export.file.present?).to be_falsey
    #     instance.perform(export.id)
    #     export.reload
    #     expect(export.progress).to eq "finished"
    #     expect(export.open_file).to eq(csv_string)
    #     expect(export.rows).to eq 1
    #   end
    # end
  end

  context "with assigned export" do
    before { instance.export = export }

    describe "bike_to_row" do
      context "default" do
        it "returns the hash we want" do
          expect(instance.bike_to_row(bike)).to eq basic_values
        end
      end
    end
  end
end
