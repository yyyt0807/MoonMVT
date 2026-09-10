# Release checklist

This checklist deliberately separates local readiness from actions that change external state.

## Local readiness

- Run formatting, all-target check and all-target tests with warnings denied.
- Run both examples and inspect their summaries.
- Regenerate public interfaces and verify no diff.
- Recount effective MoonBit source lines without `_build` or generated files.
- Confirm README, changelog, license, notices and proposal match the code.
- Confirm the repository contains no secrets, build output or unexplained third-party material.

## External release (owner command required)

- Create or select the public GitHub repository.
- Push the complete meaningful commit history.
- Confirm GitHub Actions passes on the public commit.
- Verify the public repository link without authentication.
- Publish the reviewed version to mooncakes.io.
- Verify the mooncakes page, install command and package documentation.
- Add the public repository, CI run and mooncakes links to the submission form.

No script in this repository automatically pushes or publishes.
