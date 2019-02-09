module API
  module V3
    class Organizations < API::Base
      include API::V2::Defaults

      resource :organizations do
        desc "Add an Organization to Bike Index<span class='accstr'>*</span>", {
          authorizations: { oauth2: [{ scope: :write_organizations }] },
          notes: <<-NOTES
          **Requires** `write_organizations` **in the access token** you use to create the organization.

          <hr> 
          **Location:** You may optionally include one `location` for the organization.
        NOTES
        }
        params do
          requires :name, type: String, desc: "The organization name"
          requires :website, type: String, desc: "The organization website", regexp: URI::regexp(%w(http https))
          requires :kind, type: String, desc: "The kind of organization", values: Organization.kinds

          optional :location, type: Hash, desc: "An organization's location" do
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
        post serializer: OrganizationSerializer, root: 'organization' do
          permitted = declared(params, include_missing: false)
          organization = Organization.new(
            permitted.to_hash.except("location").merge(auto_user_id: current_user.id)
          )
          if loc = permitted.location
            state = State.where(name: loc.state).first
            country = Country.where(name: loc.country).first
            location = loc.merge(state: state, country: country)
            organization.locations.build(location.to_hash)
          end

          organization.save || error!(organization.errors.full_messages, 422)
          organization
        end
      end
    end
  end
end