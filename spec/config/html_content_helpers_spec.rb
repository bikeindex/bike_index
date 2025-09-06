# frozen_string_literal: true

require "rails_helper"

# Tests to define what these helpers should do
# file is config/lib because if it was in support it would be required by rails_helper.rb
html_content = <<-HTML
  <!-- BEGIN app/views/layouts/application.html.haml -->
  <!DOCTYPE html>
  <html lang='en'>
  <head>
  <!-- BEGIN app/components/header_tags/component.html.erb --><title>Stolen 2025 bike</title>
  <meta charset="utf-8">
  <meta name="description" content="ETC">
  <script type="application/ld+json">
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Bike Index",
      "description": "The best bike registry: Simple, secure and free.",
      "url": "https://bikeindex.org",
      "image": "https://bikeindex.org/opengraph.png"
    }
  </script>
  </head>
  <body class='' id='bikes_show'>
    <nav class='primary-header-nav'>
      <div class='container'>
        <a class='primary-logo' href='http://localhost:3042/admin'>
          <img class="primary-nav" alt="Bike Index home" src="/assets/revised/logo-4743be32095c95ab594556faadf9f2497c4a49bd8a9f77a5aeadd4050c78dff9.svg" />
        </a>
        <a class="nonprofit-subtitle" href="/news/bike-index--now-a-nonprofit">the non-profit bike registry
        </a>
        <span class='current-organization-nav-item'>
          <a aria-expanded='false' aria-haspopup='true' data-toggle='dropdown' href='#' id='passive_organization_submenu'>
            Hogwarts
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" viewBox="0 0 16 16" class="tw:rotate-90 tw:inline-block tw:w-3 tw:h-3 tw:ml-1">
              <path fill-rule="evenodd" d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708"></path>
            </svg>
          </a>
        </span>
      </div>
    </nav>
    <!-- BEGIN app/components/definition_list/container/component.html.erb -->  <dl class="tw:break-words tw:@container">
      <!-- BEGIN app/components/definition_list/row/component.html.erb --><div class="tw:items-center tw:@sm:flex tw:@sm:gap-x-2 tw:@sm:pt-2 tw:pt-3 tw:leading-tight">
        <dt class="tw:@sm:text-right tw:@sm:w-1/4 tw:min-w-[100px] tw:text-sm tw:leading-none tw:opacity-65 tw:font-bold!">
          Location
        </dt>
        <dd class="tw:mb-0!">
          Oakland, CA 94608

        </dd>
      </div>
      <!-- END app/components/definition_list/row/component.html.erb -->


      <!-- BEGIN app/components/definition_list/row/component.html.erb --><div class="tw:items-center tw:@sm:flex tw:@sm:gap-x-2 tw:@sm:pt-2 tw:pt-3 tw:leading-tight">
        <dt class="tw:@sm:text-right tw:@sm:w-1/4 tw:min-w-[100px] tw:text-sm tw:leading-none tw:opacity-65 tw:font-bold!">
          Stolen at
        </dt>
        <dd class="tw:mb-0!">
            <span class="preciseTime originalTimeZone localizeTime">
              2019-05-20T07:00:00-0700
            </span>
            <span class="localizeTimezone"></span>
        </dd>
      </div>
    </dl>

    <style>.cls-1{fill:none;stroke:#a4a4a4;stroke-miterlimit:10;}</style>
    <script id="alert-template" type="x-tmpl-mustache"><div class="alert alert-{{alert_type}} in" data-seconds="{{seconds}}"> <button aria-label="Close" class="close" data-dismiss="alert" type="button"> <span aria-hidden="true">&times;</span> </button> {{alert_body}} </div> </script>
  </body>
  </html>
HTML

RSpec.describe HtmlContentHelpers do
  include HtmlContentHelpers

  describe "whitespace_normalized_body_text" do
    let(:target) do
      "the non-profit bike registry Hogwarts Location Oakland, CA 94608 Stolen at 2019-05-20T07:00:00-0700"
    end
    it "responds with target" do
      expect(whitespace_normalized_body_text(html_content)).to eq target
    end
  end
end
