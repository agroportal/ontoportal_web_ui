# Contributing

Workflow (GitHub Flow, branches, reviews, releases, hotfixes): see the
[AgroPortal contribution guidelines](https://wiki.agroportal.eu/s/aa38b012-7d19-4787-9ae5-5f9dce3a1f83).

## Commit messages

Commits and PR titles follow
[Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/).
A squash merge takes the PR title, or the commit subject when the PR has a
single commit, so both must comply.

```
<type>[(<scope>)][!]: <description>

[body]

[footer]
```

### Subject

- `type`:

  | Type       | Use for                                 |
  |------------|-----------------------------------------|
  | `feat`     | user-visible feature or behavior change |
  | `fix`      | bug fix                                 |
  | `perf`     | performance improvement                 |
  | `refactor` | code change without behavior change     |
  | `test`     | tests only                              |
  | `docs`     | documentation only                      |
  | `style`    | formatting only                         |
  | `build`    | dependencies, Docker, asset build       |
  | `ci`       | GitHub workflows                        |
  | `chore`    | anything else                           |
  | `revert`   | revert of a previous commit             |

- `scope`: optional area, e.g. `search`, `federation`, `admin`.
- `description`: imperative, lowercase, no trailing period.
- Keep the subject under 50 characters; 72 is the hard limit.

### Body

- Separate it from the subject with a blank line; wrap at 72 characters.
- Explain why and the context that led to the change. The diff shows how.
- Omit it when the subject says enough.

### Footer

- Issues: `Refs: #123` or `Closes #123`.
- Breaking changes: `!` after the type or scope, plus a `BREAKING CHANGE:`
  footer. Use it when deployed portals must act on upgrade, e.g. a renamed
  config global or environment variable.

### Examples

```
fix: hide retired OntoPortal instances on the homepage
```

```
feat(search): search agents from the navbar
```

```
refactor(federation)!: rename the federated portals setting

<why the rename was needed>

BREAKING CHANGE: <what deployed portals must change in their config>
```
