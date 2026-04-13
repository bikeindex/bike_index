# frozen_string_literal: true

module PageBlock::LandingForSchools
  class Component < ApplicationComponent
    include MoneyHelper

    def initialize(feedback: Feedback.new)
      @feedback = feedback
    end

    private

    def recoveries_value_display
      as_currency(Counts.recoveries_value / 1_000_000) + "M+"
    end

    def recoveries_display
      number_with_delimiter(Counts.recoveries)
    end

    def organizations_display
      number_with_delimiter(Counts.organizations)
    end

    def bike_tile_images
      (0..16).map { it.to_s.rjust(2, "0") }
        .map { image_url("kelsey/bike_tiles/bike-entry_00#{it}.png") }
    end

    def university_partners
      [
        {file: "CU-Boulder.png", name: "CU Boulder"},
        {file: "Penn-State.png", name: "Penn State"},
        {file: "Princeton.png", name: "Princeton"},
        {file: "Stevens-Institute-of-Technology.png", name: "Stevens Institute"},
        {file: "UC-Davis.png", name: "UC Davis"},
        {file: "UC-San-Diego.png", name: "UC San Diego"},
        {file: "UCLA.png", name: "UCLA"},
        {file: "University-of-Maryland.png", name: "University of Maryland"},
        {file: "University-of-Pittsburgh.png", name: "University of Pittsburgh"},
        {file: "University-of-Washington.png", name: "University of Washington"}
      ]
    end

    def features
      [
        {
          image: "kelsey/universities/assets-uni_1.png",
          title: "All-in-One Database",
          text: "Streamlined registration, tracking, and impound management with clear workflows for lost and stolen bike cases across all campus departments."
        },
        {
          image: "kelsey/universities/assets-uni_2.png",
          title: "Extensive Tools & Workflows",
          text: "QR stickers, searchable catalogs, direct messaging, and legacy transfer tools help you modernize operations and reduce administrative burden."
        },
        {
          image: "kelsey/universities/assets-uni_3.png",
          title: "e-Vehicle & Micromobility Management",
          text: "Manage campus vehicles, including e-personal mobility devices (EPAMDs), by verifying UL certification and centralizing safety documentation."
        }
      ]
    end

    def tools
      [
        {image: "kelsey/universities/features_database.png.png", title: "All-in-One Database", text: "Staff can access the same information on bikes, locations, and updates, fostering seamless collaboration."},
        {image: "kelsey/universities/features_catalog.png", title: "Searchable Catalog", text: "Quickly find bike details and contact information for cyclists."},
        {image: "kelsey/universities/features_direct-communication.png", title: "Direct Messaging", text: "Communicate with students and faculty regarding their bikes and track message history."},
        {image: "kelsey/universities/features_updates.png", title: "Alerts & Recovery Network", text: "Issue alerts about maintenance, theft recovery, and more utilizing our national network."},
        {image: "kelsey/universities/features_impound.png", title: "Impound Bikes With Ease", text: "Impound bikes in the field or from your dashboard and create a public searchable database."},
        {image: "kelsey/universities/features_legacy-transfer.png", title: "Legacy Transfer", text: "Import existing bike registrations into Bike Index for continuity and ease of use."},
        {image: "kelsey/universities/features_graduate.png", title: "Graduate Bikes", text: "Automatically remove bikes that are no longer on campus from your system."},
        {image: "kelsey/universities/features_qr-stickers.png", title: "QR Code Stickers", text: "Permit, track and message bike owners quickly and easily with scannable stickers."}
      ]
    end

    def testimonials
      [
        {
          quote: "Among other options, Bike Index really stands out for their commitment to creating tailored, accessible solutions, and their nonprofit, advocacy ethos.",
          author: "Ted Sweeney",
          role: "former UW Active Transportation Specialist",
          image: "kelsey/illustrations/comic-assets_bike-love-1.png"
        },
        {
          quote: "We're excited to partner with Bike Index to provide Centre Region cyclists with a more intuitive and effective bike registration and recovery service.",
          author: "Cecily Zhu",
          role: "Penn State Alternative Transportation Program Coordinator",
          image: "kelsey/illustrations/comic-assets_bike-love-2.png"
        },
        {
          quote: "It comes down to efficiency. The Bike Index features allow a university bike program to operate more efficiently and in a more timely manner. That's important when it comes to students' bikes at a large university.",
          author: "Thomas Worth",
          role: "University of Maryland Department of Transportation Services",
          image: "kelsey/illustrations/comic-assets_bike-love-3.png"
        }
      ]
    end
  end
end
