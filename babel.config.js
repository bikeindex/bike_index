module.exports = function (api) {
  var validEnv = ['development', 'test', 'production']
  var currentEnv = api.env()
  var isDevelopmentEnv = api.env('development')
  var isProductionEnv = api.env('production')
  var isTestEnv = api.env('test')

  if (!validEnv.includes(currentEnv)) {
    throw new Error(
      'Please specify a valid `NODE_ENV` or ' +
        '`BABEL_ENV` environment variables. Valid values are "development", ' +
        '"test", and "production". Instead, received: ' +
        JSON.stringify(currentEnv) +
        '.'
    )
  }

  return {
    presets: [
      "@babel/react",
      [
        '@babel/preset-env',
        {
          forceAllTransforms: true,
          useBuiltIns: 'usage',
          corejs: 3,
          modules: 'auto',
          exclude: ['transform-typeof-symbol'],
          targets: {
            "node": "current",
            "browsers": "> 1%"
          }
        }
      ]
    ].filter(Boolean),
    plugins: [
      "@babel/plugin-syntax-jsx",
      'babel-plugin-macros',
      '@babel/plugin-syntax-dynamic-import',
      '@babel/plugin-transform-destructuring',
      [
        '@babel/plugin-proposal-object-rest-spread',
        {
          useBuiltIns: true
        }
      ],
      [
        '@babel/plugin-transform-regenerator',
        {
          async: false
        }
      ]
    ].filter(Boolean)
  }
}
