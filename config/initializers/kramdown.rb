module Kramdown

  module Parser
    class Base
      def adapt_source(source)
        # We added this monkeypatch because we had 2 tests in spec/requests/documentation_request_spec.rb 
        # failing in Rails 7.1 with the following error:
        #    ActionView::Template::Error:undefined method `valid_encoding?' 
        #    for #<ActionView::OutputBuffer:0x000056417815bbb0>
        #
        # We believe we need to upgrade grape-swagger, but this would require us to upgrade grape, which 
        # requires us to upgrade to Ruby 3.0.
        # We will keep this monkey patch until we can finish the Ruby 3.0 upgrade and the tests pass 
        # without this patch.
        # 
        # See these links for more information:
        # https://github.com/gettalong/kramdown/blob/0b0a9e072f9a76e59fe2bbafdf343118fb27c3fa/lib/kramdown/parser/base.rb#L91-L92
        # https://github.com/rails/rails/pull/51023
        # https://github.com/gettalong/kramdown/pull/807

        

        if source.respond_to?(:to_s)
          source = source.to_s
        end

        unless source.valid_encoding?
          raise "The source text contains invalid characters for the used encoding #{source.encoding}"
        end
        source = source.encode('UTF-8')
        source.gsub!(/\r\n?/, "\n")
        source.chomp!
        source << "\n"
      end
    end
  end
end