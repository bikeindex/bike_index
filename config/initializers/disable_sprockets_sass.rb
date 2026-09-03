# SCSS is compiled by dartsass-rails (sass-embedded) into app/assets/builds, and
# Sprockets only serves those prebuilt CSS files. But Sprockets 4 still ships its
# own SCSS handler and registers the .scss/.sass extensions, so when a build is
# missing it falls back to compiling the source .scss and raises
# `LoadError: cannot load such file -- sassc` (the sassc gem was dropped for
# dartsass). Remove Sprockets' SCSS/SASS extensions so it never attempts that
# compilation — a missing build then surfaces as a clear "not precompiled" error.
Rails.application.config.assets.configure do |env|
  sass_exts = env.config[:mime_exts].keys.select { |ext| ext.to_s.match?(/\.(scss|sass)(\.|\z)/) }
  next if sass_exts.empty?

  env.config = env.config.merge(mime_exts: env.config[:mime_exts].except(*sass_exts)).freeze
end
