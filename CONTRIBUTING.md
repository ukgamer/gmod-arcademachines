# Submission guidelines

Before submitting a pull request, please check the following:

* Run your code through [glualinter](https://github.com/FPtje/GLuaFixer). CI has been setup using the default settings to check PRs for linter issues.
* Ensure your game has an attract mode. A blank screen is pretty boring.
* If you are developing on Metastruct, ensure your game does not depend on any MS-specific functionality. Test your game in vanilla GMod.
* If your game uses custom assets, submit a pull request to the [assets repo](https://github.com/ukgamer/gmod-arcademachines-assets) and update your URLs before submitting a pull request to this repo.
* Ensure your game functions correctly at different framerates. Use `FrameTime()` to scale animations correctly.