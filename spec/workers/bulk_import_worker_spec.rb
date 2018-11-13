require "spec_helper"

describe BulkImportWorker do
  let(:subject) { BulkImportWorker }
  let(:instance) { subject.new }
  it { is_expected.to be_processed_in :afterwards }
  let(:bulk_import) { FactoryGirl.create(:bulk_import, progress: "pending") }
  let!(:black) { FactoryGirl.create(:color, name: "Black") } # Because we use it as a default color

  let(:sample_csv_lines) do
    [
      %w[manufacturer model year color owner_email serial_number],
      ["Trek", "Roscoe 8", "2019", "Green", "test@bikeindex.org", "xyz_test"],
      ["Surly", "Midnight Special", "2018", "White", "test2@bikeindex.org", "example"]
    ]
  end
  let(:csv_lines) { sample_csv_lines }
  let(:csv_string) { csv_lines.map { |r| r.join(",") }.join("\n") }
  let(:tempfile) do
    file = Tempfile.new
    file.write(csv_lines.join("\n"))
    file.rewind
    file
  end

  describe "perform" do
    context "bulk import already processed" do
      let(:bulk_import) { FactoryGirl.create(:bulk_import, progress: "finished") }
      it "returns true" do
        allow_any_instance_of(BulkImport).to receive(:open_file) { csv_string }
        expect(instance).to_not receive(:register_bike)
        instance.perform(bulk_import.id)
      end
    end
    context "valid bike and an invalid bike with substituted header" do
      let!(:color) { FactoryGirl.create(:color, name: "White") }
      let(:target_line_error) { [2, ["Owner email can't be blank"]] }
      let(:csv_lines) do
        [
          "Product Description,Vendor,Brand,Color,Size,Serial Number,Customer Last Name,Customer First Name,Customer Email",
          '"Blah","Blah","Surly","","","XXXXX","","",""',
          '"Midnight Special","","Surly","White","19","ZZZZ","","","test2@bikeindex.org"'
        ]
      end
      after { tempfile.close && tempfile.unlink }
      it "registers bike, adds row that is an error" do
        allow_any_instance_of(BulkImport).to receive(:open_file) { File.open(tempfile.path, "r") }
        expect do
          instance.perform(bulk_import.id)
        end.to change(Bike, :count).by 1
        bulk_import.reload
        expect(bulk_import.line_import_errors).to eq([target_line_error])
        expect(bulk_import.import_errors).to eq({ line: [target_line_error] }.as_json)
        expect(bulk_import.bikes.count).to eq 1
        bike = bulk_import.bikes.first
        expect(bike.manufacturer).to eq Manufacturer.other
        expect(bike.manufacturer_other).to eq "Surly"
        expect(bike.primary_frame_color).to eq color
        expect(bike.frame_size).to eq "19in"
        expect(bike.serial_number).to eq "ZZZZ"
        expect(bike.owner_email).to eq "test2@bikeindex.org"
        expect(bike.description).to eq "Midnight Special"
        expect(BulkImport.line_errors.pluck(:id)).to eq([bulk_import.id])
      end
    end
    context "empty import" do
      let(:csv_lines) { [sample_csv_lines[0].join(","), ""] }
      it "marks the import empty" do
        allow_any_instance_of(BulkImport).to receive(:open_file) { File.open(tempfile.path, "r") }
        expect do
          instance.perform(bulk_import.id)
        end.to_not change(Bike, :count)
        bulk_import.reload
        expect(bulk_import.no_bikes?).to be_truthy
        expect(bulk_import.import_errors?).to be_falsey
        expect(BulkImport.no_bikes.pluck(:id)).to eq([bulk_import.id])
      end
    end
    context "valid file" do
      let!(:green) { FactoryGirl.create(:color, name: "Green") }
      let!(:white) { FactoryGirl.create(:color, name: "White") }
      let!(:surly) { FactoryGirl.create(:manufacturer, name: "Surly") }
      let!(:trek) { FactoryGirl.create(:manufacturer, name: "Trek") }
      let(:file_url) { "https://raw.githubusercontent.com/bikeindex/bike_index/master/public/import_all_optional_fields.csv" }
      let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
      # We're stubbing the method to use a remote file, don't pass the file in and let it use the factory default
      let!(:bulk_import) { FactoryGirl.create(:bulk_import, progress: "pending", user_id: nil, organization_id: organization.id) }
      it "creates the bikes, doesn't have any errors" do
        # In production, we actually use remote files rather than local files.
        # simulate what that process looks like by loading a remote file in the way we use open_file in BulkImport
        VCR.use_cassette("bulk_import-perform-success") do
          allow_any_instance_of(BulkImport).to receive(:open_file) { open(file_url) }
          expect do
            instance.perform(bulk_import.id)
          end.to change(Bike, :count).by 2
          bulk_import.reload
          expect(bulk_import.progress).to eq "finished"
          expect(bulk_import.bikes.count).to eq 2
          expect(bulk_import.file_import_errors).to_not be_present

          bike1 = bulk_import.bikes.reorder(:created_at).first
          expect(bike1.primary_frame_color).to eq green
          expect(bike1.serial_number).to eq "xyz_test"
          expect(bike1.owner_email).to eq "test@bikeindex.org"
          expect(bike1.manufacturer).to eq trek
          expect(bike1.creation_state.origin).to eq "bulk_import_worker"
          expect(bike1.creator).to eq organization.auto_user
          expect(bike1.creation_organization).to eq organization
          expect(bike1.year).to eq 2019
          expect(bike1.description).to eq "I love this, it's my favorite"
          expect(bike1.frame_size).to eq "29in"
          expect(bike1.frame_size_unit).to eq "in"
          expect(bike1.public_images.count).to eq 0
          bike2 = bulk_import.bikes.reorder(:created_at).last
          expect(bike2.primary_frame_color).to eq white
          expect(bike2.serial_number).to eq "example"
          expect(bike2.owner_email).to eq "test2@bikeindex.org"
          expect(bike2.manufacturer).to eq surly
          expect(bike2.creation_state.origin).to eq "bulk_import_worker"
          expect(bike2.creator).to eq organization.auto_user
          expect(bike2.creation_organization).to eq organization
          expect(bike2.year).to_not be_present
          expect(bike2.public_images.count).to eq 1
          expect(bike2.frame_size).to eq "m"
          expect(bike2.frame_size_unit).to eq "ordinal"
        end
      end
    end
  end

  context "with assigned bulk import" do
    before { instance.bulk_import = bulk_import }
    describe "process_csv" do
      after { tempfile.close && tempfile.unlink }
      context "without a header" do
        let(:csv_lines) { sample_csv_lines.slice(1, 2).map { |l| l.join(",") } }
        it "adds a file error" do
          expect(instance).to_not receive(:register_bike)
          instance.process_csv(File.open(tempfile.path, "r"))
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/invalid csv headers/i)
          expect(bulk_import.progress).to eq "finished"
        end
      end
      context "with an invalid header" do
        let(:csv_lines) { ([%w[manufacturer email name color]] + sample_csv_lines.slice(1, 2)).map { |l| l.join(",") } }
        it "adds a file error" do
          expect(instance).to_not receive(:register_bike)
          instance.process_csv(File.open(tempfile.path, "r"))
          bulk_import.reload
          expect(bulk_import.file_import_errors.to_s).to match(/invalid csv headers/i)
          expect(bulk_import.progress).to eq "finished"
        end
      end
      context "with failed row" do
        let(:error_line) { ["Surly", "Midnight Special", "2018", nil, " ", "example"] }
        let(:csv_lines) { [[sample_csv_lines[0]], [error_line]].map { |l| l.join(",") } }
        let(:target_line_error) { [2, ["Owner email can't be blank"]] }
        it "registers a bike and adds a row error" do
          instance.process_csv(File.open(tempfile.path, "r"))
          expect(instance.line_errors.count).to eq 1
          expect(instance.line_errors.first).to eq target_line_error
          expect(bulk_import.progress).to eq "ongoing"
        end
      end
      context "with two valid bikes" do
        let(:csv_lines) { sample_csv_lines.map { |l| l.join(",") } }
        let(:bparam_line1) { instance.row_to_b_param_hash(sample_csv_lines[0].map(&:to_sym).zip(sample_csv_lines[1]).to_h) }
        let(:bparam_line2) { instance.row_to_b_param_hash(sample_csv_lines[0].map(&:to_sym).zip(sample_csv_lines[2]).to_h) }
        it "calls register bike with the valid bikes" do
          expect(instance).to receive(:register_bike).with(bparam_line1) { Bike.new(id: 1) }
          expect(instance).to receive(:register_bike).with(bparam_line2) { Bike.new(id: 1) }
          instance.process_csv(File.open(tempfile.path, "r"))
          bulk_import.reload
          expect(bulk_import.import_errors).to_not be_present
          expect(bulk_import.progress).to eq "ongoing"
        end
      end
    end

    describe "row_to_b_param_hash" do
      let(:row) { sample_csv_lines[0].map(&:to_sym).zip(csv_lines[1]).to_h }
      let(:target) do
        {
          owner_email: row[:owner_email],
          manufacturer_id: "Trek",
          is_bulk: true,
          color: "Green",
          serial_number: row[:serial_number],
          year: row[:year],
          frame_model: "Roscoe 8",
          description: nil,
          frame_size: nil,
          send_email: true,
          creation_organization_id: nil
        }
      end
      describe "row_to_b_param_hash" do
        context "some extra bits" do
          it "returns the hash we want" do
            row_hash = row.merge(hidden: true, another_thing: "912913")
            expect(instance.row_to_b_param_hash(row_hash)[:bike]).to eq target
          end
        end
        context "with organization" do
          let(:organization) { FactoryGirl.create(:organization) }
          let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization, no_notify: true) }
          it "registers with organization" do
            expect(instance.row_to_b_param_hash(row)[:bike]).to eq target.merge(send_email: false, creation_organization_id: organization.id)
          end
        end
      end
    end

    describe "register bike" do
      let!(:manufacturer) { FactoryGirl.create(:manufacturer, name: "Surly") }
      context "valid organization bike" do
        let(:organization) { FactoryGirl.create(:organization_with_auto_user) }
        let!(:bulk_import) { FactoryGirl.create(:bulk_import, organization: organization) }
        let(:row) { { manufacturer: " Surly", serial_number: "na", color: nil, owner_email: "test2@bikeindex.org", year: "2018", model: "Midnight Special" } }
        it "registers a bike" do
          expect(organization.auto_user).to_not eq bulk_import.user
          expect(Bike.count).to eq 0
          expect do
            instance.register_bike(instance.row_to_b_param_hash(row))
          end.to change(Bike, :count).by 1
          bike = Bike.last

          expect(bike.owner_email).to eq row[:owner_email]
          expect(bike.manufacturer).to eq manufacturer
          expect(bike.serial_number).to eq "absent"
          expect(bike.frame_model).to eq "Midnight Special"
          expect(bike.primary_frame_color).to eq black

          creation_state = bike.creation_state
          expect(creation_state.is_bulk).to be_truthy
          expect(creation_state.origin).to eq "bulk_import_worker"
          expect(creation_state.organization).to eq organization
          expect(bike.creation_organization).to eq organization
          expect(bike.creator).to eq organization.auto_user
        end
      end
      context "not valid bike" do
        let(:row) { { manufacturer_id: "\n", serial_number: "na", color: nil } }
        let(:target_errors) { ["Owner email can't be blank"] }
        it "returns the invalid bike with errors" do
          expect do
            bike = instance.register_bike(instance.row_to_b_param_hash(row))
            expect(bike.id).to_not be_present
            expect(bike.cleaned_error_messages).to eq(target_errors)
          end.to change(Bike, :count).by 0
        end
      end
    end

    describe "rescue_blank_serials" do
      let(:blank_examples) { ["NA", "N/A", "unkown", "unkown", "           ", "none"] }
      let(:non_blank_examples) { %w[somethingna none8xc9x] }
      it "rescues blank serials, doesn't rescue non blank serials" do
        blank_examples.each do |e|
          expect(instance.rescue_blank_serial(e)).to eq "absent"
        end
        non_blank_examples.each do |e|
          expect(instance.rescue_blank_serial(e)).to_not eq "absent"
        end
      end
    end

    describe "convert_header" do
      context "headers match" do
        let(:header_string) { "ManufaCTURER,MODEL, YEAR, Stuff\n" }
        let(:target) { %i[manufacturer model year stuff] }
        it "leaves things alone" do
          expect(instance.convert_headers(header_string)).to eq target
        end
      end
      context "conversions" do
        let(:header_string) { "BRAnd, vendor,MODEL,frame_model, frame YEAR, Stuff\n" }
        let(:target) { %i[manufacturer vendor model frame_model year stuff] }
        it "returns the symbol if the symbol exists, without overwriting better terms" do
          expect(instance.convert_headers(header_string)).to eq target
        end
      end
    end
  end
end
