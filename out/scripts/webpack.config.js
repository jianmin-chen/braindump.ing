const fs = require('fs')
const path = require('path')

const entryPoints = {}
for (let entry of fs.readdirSync('src')) {
  if (!['component.js', 'utils.js'].includes(entry))
    entryPoints[entry.replace('.js', '')] = './' + path.join('src', entry)
}

module.exports = {
  entry: entryPoints,
  output: {
    path: path.resolve(__dirname, 'components'),
    filename: '[name].js'
  },
  module: {
    rules: [
      {
        test: /\.js$/,
        use: {
          loader: 'babel-loader'
        }
      }
    ]
  }
}
