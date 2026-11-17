# Working in this repo

## Branches

- `develop` is where all work lands. Branch off `develop`, open the PR **into
  `develop`**, and squash-merge it. Merging into `develop` publishes nothing.
- `main` is release-only. Merging a PR into `main` **publishes the SDK** to npm.
- `main` is the default branch, so `gh pr create` and the GitHub UI target it
  unless told otherwise. Always pass `--base develop`.
- Never open a PR into `main`, merge into it or push to it unless the user
  explicitly asks for a release or a hotfix.
- Branch names: `<type>/<github-user>/<kebab-description>`, for example
  `fix/jsantelys/session-timeout`. Types: feat, fix, chore, ci, docs, refactor,
  test.

## Versions and changelog

- Add user-facing changes under `## [Unreleased]` in `CHANGELOG.md`. Don't add a
  dated version section by hand.
- Never edit version numbers by hand. Only this command changes them, and only
  when the user is cutting a release:

  ```bash
  npm run version:set -- X.Y.Z
  ```

  `npm run version:check` shows whether every copy agrees.

## Releases (only when the user asks)

- Stable: on a branch off `develop`, run the version command above, merge that
  into `develop`, then open a PR from `develop` into `main`. Someone other than
  the author approves it and it is merged with a **merge commit** (not squash).
  The workflow publishes, then creates the `X.Y.Z` tag and GitHub Release.
- Hotfix: branch `hotfix/<name>` off `main`, run the version command for the
  patch version and open the PR into `main`. After it publishes, open a PR from
  `main` into `develop` so the fix is on `develop` too.
- Release candidate:
  `gh workflow run build.yml --ref develop -f version=X.Y.Z-rc.N`.
- Never create or push version tags. The workflows create them.
- A PR into `main` that should not release needs the `no-release` label.

## Don't touch without being asked

- `.github/workflows/`, rulesets, environments and secrets. These control what
  gets published and who can publish it.
- The public API baseline, `api/react-native-appstack-sdk.api.md`. If you change
  public API on purpose, regenerate it with `npm run api:update`, commit it with
  the change and say so. The PR needs the `api-change` label (additive) or
  `breaking`.

See RELEASING.md for the full process.
