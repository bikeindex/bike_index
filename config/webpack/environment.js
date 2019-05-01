const { environment } = require("@rails/webpacker");

const webpack = require("webpack");
environment.plugins.append(
  "Provide",
  new webpack.ProvidePlugin({
    $: "jquery",
    jQuery: "jquery"
  })
);

const ignoreLoader = {
  module: {
    rules: [
       { test: /\.test\.js$/, use: 'ignore-loader' }
    ]
  }
};
environment.config.merge(ignoreLoader)

module.exports = environment;
