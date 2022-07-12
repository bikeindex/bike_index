module API
  module V3
    class Organizations < API::Base
      include API::V2::Defaults

      resource :organizations do
        helpers do
          def allowed_write_organizations
            application_uid = current_token&.application&.uid
            allowed_write_organizations = ENV["ALLOWED_WRITE_ORGANIZATIONS"]&.split(",") || []
            allowed_write_organizations.any?(application_uid)
          end
        end

        desc "Add an Organization to Bike Index<span class='accstr'>*</span>", {
          authorizations: {oauth2: {scope: :write_organizations}},
          notes: <<-NOTES
          **Requires** `write_organizations` **in the access token** you use to create the organization.
          <hr>
          **Location:** You may optionally include `locations` for the organization.

          <hr>
          **Note:** Access to this endpoint is only available to select api clients.
          NOTES
        }
        params do
          requires :name, type: String, desc: "The organization name"
          requires :website, type: String, desc: "The organization website", regexp: URI::DEFAULT_PARSER.make_regexp(%w[http https])
          requires :kind, type: String, desc: "The kind of organization", values: Organization.user_creatable_kinds

          optional :locations, type: Array, desc: "The organization locations" do
            requires :name, type: String, desc: "The location's name"
            requires :street, type: String, desc: "The location's street"
            requires :city, type: String, desc: "The location's city"
            requires :state, type: String, desc: "The location's state", values: State.valid_names
            requires :country, type: String, desc: "The location's country", values: Country.valid_names
            optional :zipcode, type: String, desc: "The location's zipcode"
            optional :phone, type: String, desc: "The location's phone number"
          end
        end

        # POST /api/v3/organizations
        post "/" do
          error!("Unauthorized. Cannot write organizations", 401) unless allowed_write_organizations

          permitted = declared(params, include_missing: false)
          organization = Organization.new(
            permitted.to_h.except("locations").merge(auto_user_id: current_user.id)
          )

          if permitted[:locations].present?
            relations = permitted[:locations].map { |loc|
              state = State.where(name: loc[:state]).first
              country = Country.where(name: loc[:country]).first
              loc.merge(state: state, country: country).to_h
            }
            organization.locations.build(relations)
          end

          organization.save || error!(organization.errors.full_messages, 422)
          OrganizationSerializer.new(organization, root: "organization")
        end
      end
    end
  end
end
