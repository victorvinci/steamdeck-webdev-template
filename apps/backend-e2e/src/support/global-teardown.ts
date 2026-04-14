module.exports = async function () {
    // Do NOT killPort here. Nx owns the backend:serve process (started via
    // this project's dependsOn) and tracks it as a long-running task; killing
    // the port out from under Nx makes subsequent `nx run backend:serve`
    // invocations coalesce and cancel, which breaks frontend-e2e's Playwright
    // webServer in the same `nx run-many -t e2e` run.
    console.log(globalThis.__TEARDOWN_MESSAGE__);
};
