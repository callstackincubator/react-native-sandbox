import {defineConfig, globalIgnores} from 'eslint/config'
import expoConfig from 'eslint-config-expo/flat.js'
import eslintPluginPrettierRecommended from 'eslint-plugin-prettier/recommended'
import simpleImportSort from 'eslint-plugin-simple-import-sort'
import globals from 'globals'

export default defineConfig([
  globalIgnores(['**/node_modules', '**/lib']),
  expoConfig,
  eslintPluginPrettierRecommended,
  {
    plugins: {
      'simple-import-sort': simpleImportSort,
    },
    rules: {
      'simple-import-sort/imports': 'error',
      'simple-import-sort/exports': 'error',
    },
  },
  {
    files: ['**/babel.config.js', '**/react-native.config.js'],
    languageOptions: {
      globals: {
        ...globals.node,
      },
    },
  },
  // Configure Prettier
  {
    rules: {
      'prettier/prettier': [
        'error',
        {
          quoteProps: 'consistent',
          singleQuote: true,
          tabWidth: 2,
          trailingComma: 'es5',
          useTabs: false,
          semi: false,
        },
      ],
    },
  },
])
