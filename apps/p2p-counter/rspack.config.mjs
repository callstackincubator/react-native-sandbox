import path from 'node:path'
import {fileURLToPath} from 'node:url'

import * as Repack from '@callstack/repack'

const __filename = fileURLToPath(import.meta.url)
const __dirname = path.dirname(__filename)

export default {
  context: __dirname,
  entry: {
    index: './index.js',
    sandbox: './sandbox.js',
  },
  output: {
    filename: '[name].bundle',
    path: __dirname + '/dist',
  },
  resolve: {
    ...Repack.getResolveOptions(),
  },
  module: {
    rules: [
      ...Repack.getJsTransformRules(),
      ...Repack.getAssetTransformRules(),
    ],
  },
  plugins: [new Repack.RepackPlugin()],
}
