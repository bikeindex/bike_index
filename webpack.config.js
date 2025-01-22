const path    = require("path")
const webpack = require("webpack")
const mode = process.env.RAILS_ENV === "development" ? "development" : "production";

module.exports = {
  mode,
  optimization: { moduleIds: "deterministic" },
  entry: {
    application: "./app/javascript/packs/application.js"
  },
  output: {
    filename: "[name].js",
    chunkFilename: "[name]-[contenthash].digested.js",
    sourceMapFilename: "[file]-[fullhash].map",
    path: path.resolve(__dirname, '..', '..', 'app/assets/builds'),
    hashFunction: "sha256",
    hashDigestLength: 64,
  },
  plugins: [
    new webpack.optimize.LimitChunkCountPlugin({
      maxChunks: 1
    }),
    new webpack.ProvidePlugin({
      $: "jquery",
      jQuery: "jquery"
    })
  ]
}
