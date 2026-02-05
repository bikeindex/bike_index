require "rails_helper"

RSpec.describe BParam, type: :model do
  describe "scopes" do
    let!(:b_param_empty) { FactoryBot.create(:b_param, params: {bike: {}, propulsion_type_motorized: nil}) }
    let!(:b_param_no_cycle_type) { FactoryBot.create(:b_param, params: {bike: bike_params, propulsion_type_motorized: true}) }
    let(:bike_params) { {owner_email: "test@bikeindex.org"} }
    let!(:b_param_bike) { FactoryBot.create(:b_param, params: {bike: bike_params.merge(cycle_type: "bike", propulsion_type_slug: "pedal-assist")}) }
    let!(:b_param_mobility) { FactoryBot.create(:b_param, params: {bike: bike_params.merge(cycle_type: "e-Skateboard")}) }
    it "scopes correctly" do
      expect(b_param_empty.reload.params).to match_hash_indifferently({bike: {}})
      expect(b_param_bike.reload.params).to match_hash_indifferently({bike: bike_params.merge(propulsion_type_slug: "pedal-assist")})
      expect(b_param_bike.motorized?).to be_truthy
      expect(b_param_mobility.reload.cycle_type).to eq "personal-mobility"
      expect(b_param_mobility.motorized?).to be_truthy
      expect(BParam.bike_params.pluck(:id)).to match_array([b_param_empty.id, b_param_no_cycle_type.id, b_param_bike.id, b_param_mobility.id])
      expect(BParam.with_cycle_type.pluck(:id)).to match_array([b_param_mobility.id])
      expect(BParam.cycle_type_not_bike.pluck(:id)).to match_array([b_param_mobility.id])
      expect(BParam.cycle_type_bike.pluck(:id)).to match_array([b_param_empty.id, b_param_no_cycle_type.id, b_param_bike.id])

      expect(BParam.top_level_motorized.pluck(:id)).to match_array([b_param_no_cycle_type.id])
      expect(BParam.motorized.pluck(:id)).to match_array([b_param_mobility.id, b_param_no_cycle_type.id])
      expect(BParam.cycle_type_not_bike.motorized.pluck(:id)).to match_array([b_param_mobility.id])
      expect(BParam.cycle_type_not_bike_ordered.pluck(:id)).to eq([b_param_mobility.id]) # Verify scope is valid
    end
  end

  describe "bike" do
    it "returns the bike attribs" do
      b_param = BParam.new(params: {bike: {serial_number: "XXX"}})
      expect(b_param.bike["serial_number"]).to eq("XXX")
    end
    it "does not fail if there isn't a bike" do
      user = FactoryBot.create(:user)
      b_param = BParam.new(creator_id: user.id, params: {stolen: true})
      expect(b_param.save).to be_truthy
    end
  end

  describe "clean_params" do
    context "passed params" do
      it "calls the things we want it to call" do
        b_param = BParam.new
        expect(b_param).to receive(:set_foreign_keys)
        expect(b_param).to receive(:massage_if_v2)
        b_param.clean_params(bike: {cool: "lol"}.as_json)
        expect(b_param.params["bike"]["cool"]).to eq("lol") # indifferent access
      end
    end
    context "not passed params" do
      it "makes indifferent" do
        b_param = BParam.new(params: {bike: {cool: "lol"}}.as_json)
        b_param.clean_params
        expect(b_param.params["bike"]["cool"]).to eq("lol")
      end
    end
    context "existing and passed params" do
      it "makes indifferent" do
        b_param = BParam.new(params: {bike: {cool: "lol"}, stolen_record: {something: 42}}.as_json)
        merge_params = {bike: {owner_email: "foo@example.com"}, stolen_record: {phone: "171-829-2625"}}.as_json
        b_param.clean_params(merge_params)
        expect(b_param.params["bike"]["cool"]).to eq("lol")
        expect(b_param.params["bike"]["owner_email"]).to eq("foo@example.com")
        expect(b_param.params["stolen_record"]["something"]).to eq(42)
        expect(b_param.phone).to eq("1718292625")
      end
    end

    it "has before_save_callback_method of clean_params" do
      expect(BParam._save_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:filter).include?(:clean_params)).to eq(true)
    end

    it "cleans params idempotently if invoked multiple times" do
      wheel_size = FactoryBot.create(:wheel_size, iso_bsd: 559)
      color = FactoryBot.create(:color, name: "Special_name4")
      manufacturer = FactoryBot.create(:manufacturer, name: "Special name3")
      params = {
        "serial" => "69 non-example",
        "manufacturer" => manufacturer.name,
        "owner_email" => "fun_times@examples.com",
        "color" => color.name,
        "cycle_type_name" => "bike",
        "rear_wheel_bsd" => wheel_size.iso_bsd,
        "rear_tire_narrow" => true,
        "year" => 1969,
        "frame_material" => "steel",
        "is_bulk" => nil,
        "is_pos" => nil,
        "is_new" => nil
      }
      b_param = BParam.new(params: params, origin: "api_v2")

      b_param.clean_params
      clean_params1 = b_param.params

      b_param.clean_params
      clean_params2 = b_param.params

      expect(clean_params2["bike"]).to match_hash_indifferently clean_params1["bike"]
      expect(clean_params2["bike"].keys).to match_array(clean_params1["bike"].keys)
      expect(clean_params2).to eq(clean_params1)
    end
  end

  describe "massage_if_v2" do
    it "renames v2 keys" do
      p = {
        serial: "something",
        manufacturer: "something else",
        test: true,
        stolen_record: {
          date_stolen: "",
          phone: nil
        }
      }.as_json
      b_param = BParam.new(params: p, origin: "api_v2")
      b_param.massage_if_v2
      new_params = b_param.bike
      expect(new_params.key?("serial_number")).to be_truthy
      expect(new_params.key?("manufacturer")).to be_truthy
      expect(new_params.keys).to match_array(%w[manufacturer serial_number send_email])
      expect(b_param.params["test"]).to be_truthy
      expect(b_param.params["stolen"]).to be_falsey
      expect(b_param.params["stolen_record"]).not_to be_present
    end
    it "gets the organization id" do
      org = FactoryBot.create(:organization, name: "Something")
      p = {organization_slug: org.slug}
      b_param = BParam.new(params: p, origin: "api_v3") # Also works for v3
      b_param.massage_if_v2
      expect(b_param.bike["creation_organization_id"]).to eq(org.id)
    end
  end

  describe "set_foreign_keys" do
    it "calls set_foreign_keys" do
      bike = {
        handlebar_type_slug: "else",
        cycle_type_slug: "entirely",
        rear_gear_type_slug: "gears awesome",
        front_gear_type_slug: "cool gears"
      }.as_json
      b_param = BParam.new(params: {bike: bike})
      expect(b_param).to receive(:set_manufacturer_key).and_return(true)
      expect(b_param).to receive(:set_color_keys).and_return(true)
      expect(b_param).to receive(:set_wheel_size_key).and_return(true)
      expect(b_param).to receive(:set_cycle_type_key).and_return(true)
      expect(b_param).to receive(:set_rear_gear_type_slug).and_return(true)
      expect(b_param).to receive(:set_front_gear_type_slug).and_return(true)
      expect(b_param).to receive(:set_handlebar_type_key).and_return(true)
      b_param.set_foreign_keys
    end
  end

  describe "manufacturer_name" do
    context "manufacturer_id" do
      let(:manufacturer) { FactoryBot.create(:manufacturer) }
      let(:b_param) { BParam.new(params: {bike: {manufacturer_id: manufacturer.id}}) }
      it "is the manufacturers name" do
        expect(b_param.mnfg_name).to eq manufacturer.name
      end
    end
    context "other" do
      let(:b_param) { BParam.new(params: {bike: {manufacturer_id: Manufacturer.other.id, manufacturer_other: '<a href="bad_site.js">stuff</a>'}}) }
      it "is a sanitized version" do
        expect(b_param.mnfg_name).to eq("stuff")
      end
    end
  end

  describe "set_wheel_size_key" do
    it "sets rear_wheel_size_id to the bsd submitted" do
      ws = FactoryBot.create(:wheel_size, iso_bsd: "Bike")
      bike = {rear_wheel_bsd: ws.iso_bsd}
      b_param = BParam.new(params: {bike: bike})
      b_param.set_wheel_size_key
      expect(b_param.bike["rear_wheel_size_id"]).to eq(ws.id)
    end
  end

  describe "set_cycle_type_key" do
    it "sets cycle_type to the cycle type from name submitted" do
      bike = {serial_number: "gobble gobble", cycle_type_slug: " strolLeR "}
      b_param = BParam.new(params: {bike: bike})
      b_param.set_cycle_type_key
      expect(b_param.bike["cycle_type"]).to eq(:stroller)
      expect(b_param.bike["cycle_type_slug"].present?).to be_falsey
    end
  end

  describe "set_handlebar_type_key" do
    it "sets handlebar_type to the handlebar type from name submitted" do
      bike = {serial_number: "gobble gobble", handlebar_type_slug: " bmx "}
      b_param = BParam.new(params: {bike: bike})
      b_param.set_handlebar_type_key
      expect(b_param.bike["handlebar_type_slug"].present?).to be_falsey
      expect(b_param.bike["handlebar_type"]).to eq(:bmx)
    end
  end

  describe "set_manufacturer_key" do
    context "attr set on manufacturer_id" do
      context "other" do
        it "adds other manufacturer name and set the set the foreign keys" do
          bike = {manufacturer_id: "lololol"}
          b_param = BParam.new(params: {bike: bike})
          b_param.set_manufacturer_key
          expect(b_param.bike["manufacturer"]).not_to be_present
          expect(b_param.bike["manufacturer_id"]).to eq(Manufacturer.other.id)
          expect(b_param.bike["manufacturer_other"]).to eq("lololol")
        end
      end
      context "existing manufacturer" do
        let(:manufacturer) { FactoryBot.create(:manufacturer) }
        context "manufacturer name" do
          it "uses manufacturer" do
            bike = {manufacturer_id: manufacturer.id}
            b_param = BParam.new(params: {bike: bike})
            b_param.set_manufacturer_key
            expect(b_param.bike["manufacturer_id"]).to eq(manufacturer.id)
          end
        end
        context "manufacturer id" do
          it "sets the manufacturer" do
            bike = {manufacturer_id: manufacturer.id}
            b_param = BParam.new(params: {bike: bike})
            b_param.set_manufacturer_key
            expect(b_param.bike["manufacturer_id"]).to eq(manufacturer.id)
          end
        end
      end
      context "no manufacturer or manufacturer_id" do
        it "does not set anything" do
          bike = {manufacturer_id: " "}
          b_param = BParam.new(params: {bike: bike})
          b_param.set_manufacturer_key
          expect(b_param.bike["manufacturer_id"]).to be_nil
        end
      end
    end
    context "attr set on manufacturer" do
      context "other manufacturer" do
        it "adds other manufacturer name and set the set the foreign keys" do
          bike = {manufacturer: "gobble gobble"}
          b_param = BParam.new(params: {bike: bike})
          b_param.set_manufacturer_key
          expect(b_param.bike["manufacturer"]).not_to be_present
          expect(b_param.bike["manufacturer_id"]).to eq(Manufacturer.other.id)
          expect(b_param.bike["manufacturer_other"]).to eq("gobble gobble")
        end
      end
      context "existing manufacturer" do
        it "looks through book slug" do
          manufacturer = FactoryBot.create(:manufacturer, name: "Something Cycles")
          bike = {manufacturer: "something"}
          b_param = BParam.new(params: {bike: bike})
          b_param.set_manufacturer_key
          expect(b_param.bike["manufacturer"]).not_to be_present
          expect(b_param.bike["manufacturer_id"]).to eq(manufacturer.id)
        end
      end
    end
  end

  describe "additional_registration_fields" do
    let(:params_hash) { {bike: bike_params}.as_json }
    let(:b_param) { BParam.new(params: params_hash) }
    let(:target_address) do
      {street: "123 Main St", city: "Nevernever Land", postal_code: "11111", region_string: "CA", kind: "ownership"}
    end
    let(:bike) { Bike.new }
    let(:bike_params) do
      {
        serial_number: "zzz",
        organization_affiliation: "employee",
        external_image_urls: ["xxxxx"],
        bike_sticker: "xxxx",
        phone: "919929333",
        street: "123 Main St",
        city: "Nevernever Land",
        zipcode: "11111",
        state: "CA"
      }
    end
    before { allow(bike).to receive(:b_params) { [b_param] } }
    it "has the expected fields" do
      expect(described_class.address_record_attributes(b_param.bike)).to eq target_address
      expect(b_param.bike_sticker_code).to eq "xxxx"
      expect(b_param.organization_affiliation).to eq "employee"
      expect(b_param.phone).to eq "919929333"
      expect(b_param.external_image_urls).to eq(["xxxxx"])
    end
  end

  describe "gear_slugs" do
    it "sets the rear gear slug" do
      gear = FactoryBot.create(:rear_gear_type)
      bike = {rear_gear_type_slug: gear.slug}
      b_param = BParam.new(params: {bike: bike})
      b_param.set_rear_gear_type_slug
      expect(b_param.params["bike"]["rear_gear_type_slug"]).not_to be_present
      expect(b_param.params["bike"]["rear_gear_type_id"]).to eq(gear.id)
    end
    it "sets the front gear slug" do
      gear = FactoryBot.create(:front_gear_type)
      bike = {front_gear_type_slug: gear.slug}
      b_param = BParam.new(params: {bike: bike})
      b_param.set_front_gear_type_slug
      expect(b_param.params["bike"]["front_gear_type_slug"]).not_to be_present
      expect(b_param.params["bike"]["front_gear_type_id"]).to eq(gear.id)
    end
  end

  describe "set_color_key" do
    let(:b_param) { BParam.new(params: {bike: bike}) }
    let!(:color) { FactoryBot.create(:color, name: "Teal") }
    let(:bike) { {color: color.name} }
    before { b_param.set_color_keys }

    it "sets the color if it's a color and remove the color attr" do
      expect(b_param.bike).to match_hash_indifferently({primary_frame_color_id: color.id})
    end
    context "not a color" do
      let(:bike) { {color: "Goop"} }
      let(:target) { {paint_name: "goop", primary_frame_color_id: Color.black.id} }
      it "sets paint and makes primary_frame_color black" do
        expect(b_param.bike.except("paint_id")).to match_hash_indifferently target
        expect(b_param.bike["paint_id"]).to eq Paint.friendly_find_id("goop")
      end
    end
    context "color and primary_frame_color set" do
      let(:bike) { {color: "Sea Green", primary_frame_color: "teal"} }
      let(:target) { {paint_name: "sea green", primary_frame_color_id: color.id} }
      it "sets the color keys" do
        expect(b_param.bike.except("paint_id")).to match_hash_indifferently target
      end
      context "unknown secondary_frame_color" do
        let(:bike) { {color: "Sea green", primary_frame_color: "teal", secondary_frame_color: "something else"} }
        it "ignores secondary_frame_color" do
          expect(b_param.bike.except("paint_id")).to match_hash_indifferently target
        end
      end
      context "secondary_frame_color" do
        let(:bike) { {color: "Sea green", primary_frame_color: "teal", secondary_frame_color: " TEAL\n"} }
        it "ignores secondary_frame_color" do
          expect(b_param.bike.except("paint_id")).to match_hash_indifferently target.merge(secondary_frame_color_id: color.id)
        end
      end
    end
  end

  describe "set_paint_key" do
    it "associates the paint and set the color if it can" do
      color = FactoryBot.create(:color, name: "Yellow")
      paint = FactoryBot.create(:paint, name: "pinkly butter", color_id: color.id)
      b_param = BParam.new(params: {bike: {color: paint.name}})
      b_param.set_paint_key(paint.name)
      expect(b_param.bike["paint_id"]).to eq(paint.id)
      expect(b_param.bike["primary_frame_color_id"]).to eq(color.id)
    end

    it "creates a paint and set the color to black if we don't know the color" do
      black = Color.black
      b_param = BParam.new(params: {bike: {}})
      expect {
        b_param.set_paint_key("Paint 69")
      }.to change(Paint, :count).by(1)
      expect(b_param.bike["paint_id"]).to eq(Paint.find_by_name("paint 69").id)
      expect(b_param.bike["primary_frame_color_id"]).to eq(black.id)
    end

    it "associates the manufacturer with the paint if it's a new bike" do
      m = FactoryBot.create(:manufacturer)
      bike = {is_pos: true, manufacturer_id: m.id}
      b_param = BParam.new(params: {bike: bike})
      b_param.set_paint_key("paint 69")
      p = Paint.find_by_name("paint 69")
      expect(p.manufacturer_id).to eq(m.id)
    end
  end

  describe "generate_username_confirmation_and_auth" do
    it "generates the required tokens" do
      b_param = BParam.new
      b_param.generate_id_token
      expect(b_param.id_token.length).to be > 10
    end
    it "haves before create callback" do
      expect(BParam._create_callbacks.select { |cb| cb.kind.eql?(:before) }.map(&:filter).include?(:generate_id_token)).to eq(true)
    end
  end

  #
  # Revised attrs
  describe "find_or_new_from_token" do
    let(:user) { FactoryBot.create(:user) }
    #
    # Because for now we aren't updating the factory, use this let for b_params factory
    let(:b_param) { BParam.create }
    let(:expire_b_param) { b_param.update_attribute :created_at, Time.current - 5.weeks }
    context "with user_id passed" do
      context "without token" do
        it "returns a new b_param, with creator of user_id" do
          result = BParam.find_or_new_from_token(nil, user_id: user.id)
          expect(result.is_a?(BParam)).to be_truthy
          expect(result.id).to be_nil
          expect(result.creator_id).to eq user.id
        end
      end
      context "existing token" do
        context "with creator of same user and expired b_param" do
          it "returns the b_param - also testing that we get the *correct* b_param" do
            expire_b_param
            BParam.create(creator_id: user.id)
            b_param.update_attribute :creator_id, user.id
            expect(BParam.find_or_new_from_token(b_param.id_token, user_id: user.id)).to eq b_param
          end
        end
        context "with creator of different user" do
          it "fails" do
            other_user = FactoryBot.create(:user)
            b_param.update_attribute :creator_id, user.id
            result = BParam.find_or_new_from_token(b_param.id_token, user_id: other_user.id)
            expect(result.is_a?(BParam)).to be_truthy
            expect(result.id).to be_nil
          end
        end
        context "with no creator" do
          it "returns the b_param" do
            result = BParam.find_or_new_from_token(b_param.id_token, user_id: user.id)
            expect(result.id).to eq b_param.id
          end
          context "with expired b_param" do
            it "fails" do
              expire_b_param
              result = BParam.find_or_new_from_token(b_param.id_token, user_id: user.id)
              expect(result.is_a?(BParam)).to be_truthy
              expect(result.id).to be_nil
            end
          end
        end
      end
      it "updates with the organization" do
        organization_id = 42
        result = BParam.find_or_new_from_token(user_id: user.id, organization_id: organization_id)
        expect(result.is_a?(BParam)).to be_truthy
        expect(result.creation_organization_id).to eq(organization_id)
        expect(result.creator_id).to eq(user.id)
        expect(result.id).to be_nil
      end
      context "with existing bike" do
        it "fails and says expired" do
          b_param.update_attribute :created_bike_id, 33
          result = BParam.find_or_new_from_token(b_param.id_token)
          expect(result.is_a?(BParam)).to be_truthy
          expect(result.id).to be_nil
        end
      end
    end
    context "without user_id passed" do
      context "without token" do
        it "returns a new b_param" do
          result = BParam.find_or_new_from_token
          expect(result.is_a?(BParam)).to be_truthy
          expect(result.id).to be_nil
        end
      end
      context "with organization" do
        context "organization not set" do
          it "updates with the organization" do
            organization_id = 42
            result = BParam.find_or_new_from_token(b_param.id_token, organization_id: organization_id)
            expect(result).to eq b_param
            expect(result.creation_organization_id).to eq(organization_id)
          end
        end
      end
      context "without user" do
        it "returns the b_param also testing that we get the *correct* b_param" do
          BParam.create
          expect(BParam.find_or_new_from_token(b_param.id_token)).to eq b_param
          expect(BParam.first).to_not eq b_param # Ensuring we aren't picking it accidentally
        end
        context "expired_b_param" do
          it "returns new b_param" do
            expire_b_param
            result = BParam.find_or_new_from_token(b_param.id_token)
            expect(result.is_a?(BParam)).to be_truthy
            expect(result.id).to be_nil
          end
        end
        context "with creator" do
          it "returns new b_param" do
            b_param.update_attribute :creator_id, user.id
            result = BParam.find_or_new_from_token(b_param.id_token)
            expect(result.is_a?(BParam)).to be_truthy
            expect(result.id).to be_nil
          end
        end
      end
    end
    context "with existing b_param with nil for id_token value - legacy issue" do
      let(:b_param_nil) { FactoryBot.create(:b_param, creator_id: user.id) }
      it "does not return that BParam" do
        b_param_nil.update_column :id_token, nil
        b_param_nil.reload
        result = BParam.find_or_new_from_token(nil, user_id: user.id)
        expect(result.is_a?(BParam)).to be_truthy
        expect(result.id).to be_nil
        expect(result.creator_id).to eq user.id
      end
    end
  end

  describe "display_email?" do
    context "owner_email present" do
      it "is false" do
        b_param = BParam.new(params: {bike: {owner_email: "something@stuff.com"}.with_indifferent_access})
        expect(b_param.display_email?).to be_falsey
      end
    end
    context "owner_email not present" do
      it "is true" do
        b_param = BParam.new(params: {bike: {owner_email: ""}.with_indifferent_access})
        expect(b_param.display_email?).to be_truthy
      end
    end
    context "Bike has errors" do
      it "is true" do
        b_param = BParam.new(params: {
          bike: {owner_email: "something@stuff.com"}.with_indifferent_access
        }, bike_errors: ["Some error"])
        expect(b_param.display_email?).to be_truthy
      end
    end
  end

  describe "status_hash_from_params" do
    let(:params) { ActionController::Parameters.new(params_hash) }
    def acparams(hash)
      ActionController::Parameters.new(hash)
    end
    it "returns empty" do
      expect(BParam.status_hash_from_params).to eq({})
      expect(BParam.status_hash_from_params(acparams(status: "asdfasdfasdfasdf"))).to eq({})
      expect(BParam.status_hash_from_params(acparams(status: "status_party"))).to eq({})
      expect(BParam.status_hash_from_params(acparams(status: nil))).to eq({})
      expect(BParam.status_hash_from_params(acparams(stolen: nil))).to eq({})
      expect(BParam.status_hash_from_params(acparams(status: nil, stolen: nil))).to eq({})
    end
    context "with stolen value" do
      it "returns empty" do
        expect(BParam.status_hash_from_params(acparams(stolen: nil))).to eq({})
        expect(BParam.status_hash_from_params(acparams(stolen: "false"))).to eq({})
        expect(BParam.status_hash_from_params(acparams(stolen: 0))).to eq({})
      end
    end
    context "stolen truthy" do
      it "returns stolen" do
        expect(BParam.status_hash_from_params(acparams(stolen: true))).to eq({status: "status_stolen"})
        expect(BParam.status_hash_from_params(acparams(stolen: "true"))).to eq({status: "status_stolen"})
        expect(BParam.status_hash_from_params(acparams(stolen: 1))).to eq({status: "status_stolen"})
        expect(BParam.status_hash_from_params(acparams(stolen: 1, status: nil))).to eq({status: "status_stolen"})
      end
    end
    context "status_stolen" do
      it "returns stolen" do
        expect(BParam.status_hash_from_params(acparams(status: "status_stolen"))).to eq({status: "status_stolen"})
        expect(BParam.status_hash_from_params(acparams(status: "stolen"))).to eq({status: "status_stolen"})
        expect(BParam.status_hash_from_params(acparams(status: "stolen", stolen: nil))).to eq({status: "status_stolen"})
      end
    end
    context "status_impounded" do
      it "returns impounded" do
        expect(BParam.status_hash_from_params(acparams(status: "status_impounded"))).to eq({status: "status_impounded"})
        expect(BParam.status_hash_from_params(acparams(status: "impounded"))).to eq({status: "status_impounded"})
        expect(BParam.status_hash_from_params(acparams(status: "impounded", stolen: "1"))).to eq({status: "status_impounded"})
      end
      context "found" do
        it "returns impounded" do
          expect(BParam.status_hash_from_params(acparams(status: "found"))).to eq({status: "status_impounded"})
          expect(BParam.status_hash_from_params(acparams(status: "found", stolen: true))).to eq({status: "status_impounded"})
        end
      end
    end
  end

  describe "partial_resent_notifications" do
    let(:b_param) { FactoryBot.create(:b_param_partial_registration, created_at: created_at) }
    let(:created_at) { Time.current }
    before { Email::PartialRegistrationJob.new.perform(b_param.id) }
    it "doesn't include initial notification" do
      expect(b_param.partial_notification_pre_tracking?).to be_falsey
      expect(b_param.partial_notifications.count).to eq 1
      expect(b_param.partial_notification_resends.count).to eq 0
      Email::PartialRegistrationJob.new.perform(b_param.id)
      b_param.reload
      expect(b_param.partial_notifications.count).to eq 2
      expect(b_param.partial_notification_resends.count).to eq 1
    end
    context "pre time" do
      let(:created_at) { Time.at(1690590595) } # 2023-07-28 19:29:55
      it "includes initial notification" do
        expect(b_param.partial_notification_pre_tracking?).to be_truthy
        expect(b_param.partial_notifications.count).to eq 1
        expect(b_param.partial_notification_resends.count).to eq 1
      end
    end
  end

  describe "propulsion_type" do
    context "with propulsion_type" do
      let(:passed_params) { {bike: {propulsion_type: "not-a-valid-propulsion-type"}} }
      it "assigns the propulsion_type_slug" do
        expect(BParam.propulsion_type(passed_params.as_json)).to eq "not-a-valid-propulsion-type"
        expect(BParam.propulsion_type(passed_params[:bike].as_json)).to eq "not-a-valid-propulsion-type"
      end
    end
    context "with propulsion_type_slug" do
      let(:passed_params) { {bike: {propulsion_type_slug: "human-not-pedal", propulsion_type: "not-a-valid-propulsion-type"}} }
      it "assigns the propulsion_type_slug" do
        expect(BParam.propulsion_type(passed_params.as_json)).to eq "human-not-pedal"
        expect(BParam.propulsion_type(passed_params[:bike].as_json)).to eq "human-not-pedal"
      end
    end
    context "with propulsion_type_slug and top_level_propulsion_type" do
      let(:passed_params) { {propulsion_type_motorized: "1", bike: {propulsion_type_slug: "human-not-pedal"}} }
      it "assigns the top_level_propulsion_type" do
        expect(BParam.propulsion_type(passed_params.as_json)).to eq "motorized"
      end
    end
    context "propulsion_type" do
      it "is foot-pedal" do
        expect(BParam.propulsion_type({})).to be_nil
      end
      context "propulsion_type_throttle" do
        let(:pparams) { {"propulsion_type_throttle" => "1"} }
        it "is throttle" do
          expect(BParam.propulsion_type(pparams)).to eq "throttle"
        end
        context "with propulsion_type_pedal_assist" do
          let(:pparams_with_assist) { pparams.merge("propulsion_type_pedal_assist" => true) }
          it "is pedal-assist-and-throttle" do
            expect(BParam.propulsion_type(pparams_with_assist)).to eq "pedal-assist-and-throttle"
          end
        end
        context "with propulsion_type_motorized" do
          let(:pparams_motorized) { pparams.merge("propulsion_type_motorized" => "1") }
          it "is throttle" do
            expect(BParam.propulsion_type(pparams)).to eq "throttle"
          end
        end
      end
      context "propulsion_type_motorized" do
        let(:pparams) { {"propulsion_type_motorized" => "1"} }
        it "is throttle" do
          expect(BParam.propulsion_type(pparams)).to eq "motorized"
        end
      end
    end
  end

  describe "safe_bike_attrs" do
    let(:b_param) { BParam.new(params: params) }
    let(:bike_params) { {owner_email: "stuff@something.com", propulsion_type: "foot-pedal"} }
    let(:params) { {bike: bike_params} }
    let(:target) do
      {
        owner_email: "stuff@something.com",
        b_param_id: nil,
        b_param_id_token: nil,
        creator_id: nil,
        updator_id: nil,
        status: "status_with_owner",
        propulsion_type_slug: "foot-pedal"
      }
    end
    it "responds with bike_attrs" do
      expect(b_param.safe_bike_attrs({})).to match_hash_indifferently target
      expect(b_param.safe_bike_attrs({})).to_not have_key(:address_record_attributes)
    end
    context "with new_attrs" do
      it "uses the new_attrs" do
        expect(b_param.safe_bike_attrs({"owner_email" => "e@f.g"})).to match_hash_indifferently target.merge(owner_email: "e@f.g")
      end
    end
    context "with location attrs" do
      let!(:organization) { FactoryBot.create(:organization) }
      let!(:state) { FactoryBot.create(:state, :find_or_create, abbreviation: "CO", name: "Colorado") }
      let(:target) do
        {
          email: "stuff@example.com",
          embeded: "true",
          b_param_id: nil,
          b_param_id_token: nil,
          status: "status_with_owner",
          propulsion_type_slug: nil,
          creator_id: nil,
          updator_id: nil,
          phone: "1112223333",
          student_id: "99999999",
          address_record_attributes: {
            city: "Golden",
            country_id: Country.united_states_id,
            region_string: "CO",
            street: "1812 Miners Spur, Building 2015 Unit 99999-69",
            postal_code: "80401",
            kind: "ownership"
          }
        }
      end
      context "with address_record" do
        let(:bike_params) do
          {
            phone: "1112223333",
            student_id: "99999999",
            email: "stuff@example.com",
            embeded: "true",
            address_record_attributes: {
              city: "Golden",
              region_string: "CO",
              street: "1812 Miners Spur, Building 2015 Unit 99999-69",
              postal_code: "80401",
              country_id: Country.united_states_id
            }
          }
        end
        it "returns target attributes" do
          expect(described_class.address_record_attributes(b_param.bike).except(:region_record_id))
            .to match_hash_indifferently target[:address_record_attributes].except(:region_record_id)
          expect(b_param.safe_bike_attrs({})).to match_hash_indifferently target
        end
      end
      context "with legacy attributes" do
        let(:bike_params) do
          {
            city: "Golden",
            phone: "1112223333",
            state: "CO",
            street: "1812 Miners Spur, Building 2015 Unit 99999-69",
            embeded: "true",
            zipcode: "80401",
            country_id: Country.united_states_id,
            student_id: "99999999",
            email: "stuff@example.com"
          }
        end
        it "returns target attributes" do
          expect(described_class.address_record_attributes(b_param.bike))
            .to match_hash_indifferently target[:address_record_attributes]
          expect(b_param.safe_bike_attrs({})).to match_hash_indifferently target
        end
      end
    end
    context "top_level_propulsion_type" do
      let(:params) { {propulsion_type_motorized: 1, bike: bike_params} }
      it "returns with propulsion_type overridden" do
        result = b_param.safe_bike_attrs({})
        expect(result).to match_hash_indifferently target.merge(propulsion_type_slug: "motorized")
        expect(result.keys).to include "propulsion_type_slug"
      end
      context "more top_level_propulsion_type options" do
        let(:params) { {propulsion_type_motorized: 1, propulsion_type_throttle: 0, propulsion_type_pedal_assist: 1, bike: bike_params} }
        it "returns with propulsion_type overridden" do
          result = b_param.safe_bike_attrs({})
          expect(result).to match_hash_indifferently target.merge(propulsion_type_slug: "pedal-assist")
          expect(result.keys).to include "propulsion_type_slug"
        end
      end
    end
    context "with untranslateable unicode escape sequence" do
      let(:bike_params) { {owner_email: "\nsomething@ss.\u0000", cycle_type: "\n", propulsion_type_motorized: "false"} }
      let(:target_result) { target.merge(owner_email: "something@ss.", propulsion_type_motorized: "false", propulsion_type_slug: nil) }
      it "makes it valid" do
        result = b_param.safe_bike_attrs({})
        expect(result).to match_hash_indifferently target_result
      end
    end
    context "with cycle_type" do
      let(:bike_params) { {owner_email: "stuff@something.com", propulsion_type_slug: "foot-pedal", cycle_type: "tandem"} }
      # propulsion_type_slug verifies the propulsion type is valid for the cycle type in bike_attributable,
      # if cycle_type hasn't been set yet, it doesn't work. So test that it is in the back
      it "makes propulsion_type_slug the last element" do
        result = b_param.safe_bike_attrs({})
        expect(result).to match_hash_indifferently target.merge(cycle_type: "tandem", propulsion_type_slug: "foot-pedal")
        expect(result.keys).to include "propulsion_type_slug"
      end
    end
  end
end
