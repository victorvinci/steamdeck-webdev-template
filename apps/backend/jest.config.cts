module.exports = {
    displayName: 'backend',
    preset: '../../jest.preset.js',
    testEnvironment: 'node',
    transform: {
        '^.+\\.[tj]s$': ['ts-jest', { tsconfig: '<rootDir>/tsconfig.spec.json' }],
    },
    moduleFileExtensions: ['ts', 'js', 'html'],
    coverageDirectory: '../../coverage/apps/backend',
    // Without `collectCoverageFrom`, Jest only reports coverage for files
    // actually touched by tests — which makes "100% coverage" trivially
    // true even when most source files have no tests. Listing everything
    // under src/ makes uncovered files show up as 0% so the threshold
    // below can actually fail on real regressions.
    //
    // Excludes:
    //   - main.ts            wiring + listen(), exercised via backend-e2e
    //   - routes/**          thin glue, exercised via backend-e2e
    //   - types.d.ts         ambient declarations, no executable code
    //   - *.spec.ts          tests themselves
    collectCoverageFrom: [
        'src/**/*.ts',
        '!src/main.ts',
        '!src/routes/**',
        '!src/types.d.ts',
        '!src/**/*.spec.ts',
    ],
    coverageThreshold: {
        // Floor calibrated below current actuals (see CHANGELOG entry for
        // the run that produced these numbers). Bumps go in their own PRs
        // once new tests land — never bump in the same PR that shipped
        // the coverage gain, so the threshold stays a regression net,
        // not a goalpost that follows the ball.
        global: {
            // Calibrated 2026-04-27 against:
            //   statements 58.46  branches 64.28  lines 57.14  functions 75
            // Floors set ~5% below actuals to absorb churn without false
            // positives on minor refactors.
            statements: 50,
            branches: 60,
            lines: 50,
            functions: 70,
        },
    },
};
