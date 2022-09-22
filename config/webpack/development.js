process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const environment = require('./environment')

// livereload on view file changes h/t https://github.com/rails/webpacker/issues/1879
const chokidar = require('chokidar')
environment.config.devServer.before = (app, server) => {
  chokidar
    .watch(['app/views/**/*.haml'])
    .on('change', () => server.sockWrite(server.sockets, 'content-changed'))
}

module.exports = environment.toWebpackConfig()
