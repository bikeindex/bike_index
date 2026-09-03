require "rails_helper"

RSpec.shared_examples "bike_attributable" do
  let(:model_sym) { subject.class.name.underscore.to_sym }
  let(:instance) { FactoryBot.create model_sym }

  describe "frame_colors" do
    it "returns an array of the frame colors" do
      black = Color.new(name: "Black")
      blue = Color.new(name: "Blue")
      obj = subject.class.new(primary_frame_color: blue, secondary_frame_color: black)
      expect(obj.frame_colors).to eq(%w[Blue Black])
    end
  end

  describe "video_embed_src" do
    # Currently unused, but could be used to clean up video URLs in the future (like it once was)
    let(:obj) { subject.class.new(video_embed: video_embed) }
    let(:video_embed) { " " }
    it "returns false if there is no video_embed" do
      obj = subject.class.new
      expect(obj.video_embed_src).to be_nil
    end
    context "youtube" do
      let(:video_embed) { '<iframe width="560" height="315" src="//www.youtube.com/embed/Sv3xVOs7_No" frameborder="0" allowfullscreen></iframe>' }
      it "returns just the url of the video from a youtube iframe" do
        expect(obj.video_embed_src).to eq("//www.youtube.com/embed/Sv3xVOs7_No")
      end
    end
    context "vimeo" do
      let(:video_embed) { '<iframe src="http://player.vimeo.com/video/13094257" width="500" height="281" frameborder="0" webkitAllowFullScreen mozallowfullscreen allowFullScreen></iframe><p><a href="http://vimeo.com/13094257">Fixed Gear Kuala Lumpur, RatsKL Putrajaya</a> from <a href="http://vimeo.com/user3635109">irmanhilmi</a> on <a href="http://vimeo.com">Vimeo</a>.</p>' }
      it "returns just the url of the video from a vimeo iframe" do
        expect(obj.video_embed_src).to eq("http://player.vimeo.com/video/13094257")
      end
    end
  end

  describe "type" do
    let(:obj) { FactoryBot.build(model_sym, cycle_type: type, propulsion_type: propulsion_type) }
    let(:type) { "trailer" }
    let(:propulsion_type) { "foot-pedal" }
    it "returns the cycle type name" do
      expect(obj.type).to eq("bike trailer")
      expect(obj.type_titleize).to eq("Bike Trailer")
      expect(obj.propulsion_titleize).to eq("Pedal")
    end
    context "e-scooter" do
      let(:type) { "e-scooter" }
      let(:propulsion_type) { "throttle" }
      it "returns expected" do
        expect(obj.type).to eq "e-scooter"
        expect(obj.type_titleize).to eq "e-Scooter"
        expect(obj.propulsion_titleize).to eq "Throttle"
      end
    end
    context "pedal-assist" do
      let(:type) { "bike" }
      let(:propulsion_type) { "pedal-assist" }
      it "returns expected" do
        expect(obj.propulsion_titleize).to eq "Pedal Assist"
      end
    end
    context "pedal-assist-and-throttle" do
      let(:type) { "bike" }
      let(:propulsion_type) { "pedal-assist-and-throttle" }
      it "returns expected" do
        expect(obj.propulsion_titleize).to eq "Pedal Assist and Throttle"
      end
    end
    context "personal-mobility" do
      let(:type) { "personal-mobility" }
      let(:propulsion_type) { "throttle" }
      it "returns expected" do
        expect(obj.cycle_type_name).to eq "e-Personal Mobility (EPAMD, e-Skateboard, Segway, e-Unicycle, etc)"
        expect(obj.type).to eq "e-personal mobility"
        expect(obj.type_titleize).to eq "e-Personal Mobility"
        expect(obj.propulsion_titleize).to eq "Throttle"
      end
    end
  end

  describe "handlebar_type_name" do
    let(:obj) { FactoryBot.build(model_sym, handlebar_type: "bmx") }
    it "returns the normalized name" do
      normalized_name = HandlebarType.new(obj.handlebar_type).name
      expect(obj.handlebar_type_name).to eq(normalized_name)
    end
  end

  describe "cycle_type_name" do
    let(:obj) { FactoryBot.build(model_sym, cycle_type: "cargo") }
    it "returns the normalized name" do
      normalized_name = CycleType.new(obj.cycle_type).name
      expect(obj.cycle_type_name).to eq(normalized_name)
    end
  end

  describe "propulsion_type_name" do
    let(:obj) { FactoryBot.build(model_sym, propulsion_type_slug: "pedal-assist") }
    it "returns the normalized name" do
      normalized_name = PropulsionType.new(obj.propulsion_type).name
      expect(obj.propulsion_type_name).to eq(normalized_name)
    end
  end

  describe "drivetrain_attributes" do
    let(:obj) { FactoryBot.build(model_sym, coaster_brake:, belt_drive:) }
    let(:coaster_brake) { false }
    let(:belt_drive) { false }
    it "returns empty" do
      expect(obj.drivetrain_attributes).to eq ""
    end
    context "with belt_drive and coaster_brake" do
      let(:coaster_brake) { true }
      let(:belt_drive) { true }
      it "returns empty" do
        expect(obj.drivetrain_attributes).to eq "Coaster brake, Belt drive"
      end
    end
  end

  describe "propulsion_type_slug" do
    let(:obj) { FactoryBot.build(model_sym, propulsion_type_slug: propulsion_type, cycle_type: cycle_type) }
    let(:cycle_type) { "bike" }
    let(:propulsion_type) { "hand-pedal" }
    it "assigns" do
      expect(obj.propulsion_type).to eq "hand-pedal"
    end
    context "name" do
      let(:propulsion_type) { "Hand CYCLE (hand pedal)" }
      it "assigns" do
        expect(obj.propulsion_type).to eq "hand-pedal"
      end
    end
    context "short name" do
      let(:propulsion_type) { "Hand Cycle (hand pedal)" }
      it "assigns" do
        expect(obj.propulsion_type).to eq "hand-pedal"
      end
    end
    context "motorized" do
      let(:propulsion_type) { "motorized" }
      it "assigns default motorized type" do
        expect(obj.propulsion_type).to eq "pedal-assist"
      end
    end
    context "nil" do
      let(:propulsion_type) { nil }
      it "assigns default type" do
        expect(obj.propulsion_type).to eq "foot-pedal"
      end
    end
    context "random thing" do
      let(:propulsion_type) { "random-thing" }
      it "assigns default type" do
        expect(obj.propulsion_type).to eq "foot-pedal"
      end
      context "e-scooter" do
        let(:cycle_type) { "e-scooter" }
        it "assigns default type for scooter" do
          expect(obj.propulsion_type).to eq "throttle"
        end
      end
    end
    context "motorized" do
      let(:propulsion_type) { "motorized" }
      it "assigns pedal-assist" do
        expect(obj.propulsion_type).to eq "pedal-assist"
      end
      context "not cycle_type" do
        let(:cycle_type) { "wheelchair" }
        it "assigns throttle" do
          expect(obj.propulsion_type).to eq "throttle"
        end
      end
    end
  end

  describe "cached_data_array" do
    let(:manufacturer) { FactoryBot.create(:manufacturer, name: "Surly") }
    let(:primary_frame_color) { Color.friendly_find("Purple") || FactoryBot.create(:color, name: "Purple") }
    let(:secondary_frame_color) { Color.friendly_find("Red") || FactoryBot.create(:color, name: "Red") }
    let(:tertiary_frame_color) { Color.friendly_find("Silver, gray or bare metal") || FactoryBot.create(:color, name: "Silver, gray or bare metal") }
    let(:rear_wheel_size) { FactoryBot.create(:wheel_size, name: "26") }
    let(:front_wheel_size) { FactoryBot.create(:wheel_size, name: "20") }
    let(:paint) { FactoryBot.create(:paint, name: "fluorescent green") }
    let(:obj) do
      FactoryBot.create(model_sym,
        manufacturer:,
        cycle_type: "cargo",
        propulsion_type: "pedal-assist",
        frame_material: "steel",
        year: 2020,
        frame_model: "Cross-Check",
        frame_size: "m",
        primary_frame_color:,
        secondary_frame_color:,
        tertiary_frame_color:,
        rear_wheel_size:,
        front_wheel_size:,
        extra_registration_number: "EXTRA-123",
        paint:)
    end
    it "includes all cached attributes" do
      expect(obj.cached_data_array).to match_array([
        obj.mnfg_name,
        obj.propulsion_type_name,
        obj.year,
        obj.primary_frame_color.name,
        obj.secondary_frame_color.name,
        obj.tertiary_frame_color.name,
        "fluorescent green",
        obj.frame_material_name,
        obj.frame_size,
        obj.frame_model,
        "#{obj.rear_wheel_size.name} wheel",
        "#{obj.front_wheel_size.name} wheel",
        obj.extra_registration_number,
        obj.type
      ])
    end
  end

  describe "status_humanized" do
    let(:obj) { FactoryBot.build(model_sym) }
    it "returns" do
      expect(obj.status_humanized).to eq "with owner"
      expect(obj.status_humanized_no_with_owner).to eq("")
    end
  end
end
