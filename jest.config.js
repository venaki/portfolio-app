/** @type {import('ts-jest').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  moduleNameMapper: {
    '^uuid$': '<rootDir>/node_modules/uuid/dist-node/index.js',
  },
  globals: {
    'ts-jest': {
      tsconfig: {
        strict: true,
      },
    },
  },
};
