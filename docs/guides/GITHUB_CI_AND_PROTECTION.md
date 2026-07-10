# GitHub CI And Branch Protection

Three workflows protect proposed changes:

- `CI Core / windows-core`: Windows governance, workflow smoke, registry, and repository boundary.
- `CI Dashboard / dashboard`: Linux frontend lint/build and backend compile/import. It does not claim Windows runtime verification.
- `CI Security / repository-boundary`: generated artifact, file size, secret-pattern, and local environment path checks.

After the workflows have run successfully on a pull request, protect `master` with pull requests required, required checks enabled, branch-current enforcement, force pushes disabled, and branch deletion disabled. Do not configure required check names before GitHub has observed them.
