module GrapeLogging
  module Loggers
    class CloudflareIp < GrapeLogging::Loggers::Base
      def parameters(request, _)
        { ip: request.env['CF-Connecting-IP'] || request.env["REMOTE_ADDR"] }
      end
    end
  end
end