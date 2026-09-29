---
name: release-notes
description: Complete the notes of a published AgroPortal release. semantic-release writes one line per Conventional Commit; this rewrites them in the house style with authors, companion backend PRs and backend-only changes. Use after the Release workflow publishes a version.
argument-hint: "[tag, default: latest release]"
allowed-tools:
  - Bash(gh release view:*)
  - Bash(gh release list:*)
  - Bash(gh pr view:*)
  - Bash(gh pr list:*)
  - Bash(git fetch:*)
  - Bash(git log:*)
---

# Complete release notes

Release: $ARGUMENTS (the latest published release when empty).

Always pass `-R agroportal/<repo>` to `gh`; without it, `gh` may resolve to
`ontoportal/ontoportal_web_ui`.

## 1. Find the range

- `gh release list -R agroportal/ontoportal_web_ui --exclude-drafts --exclude-pre-releases --json tagName,publishedAt`
- Target: the release. Previous: the one published right before it.
- `git fetch origin --tags`
- The generated body (`gh release view <tag> --json body`) is a starting
  point only: it drops every commit that isn't a Conventional Commit.

## 2. Collect UI PRs

- `git log <previous>..<target> --format='%H%x09%s'`
- Map each commit to its PR: `(#N)` or `Merge pull request #N` in the
  subject, else `gh pr list --state merged --search <sha>`. If `#N` isn't a
  PR of this repo (e.g. a security advisory fork), ask.
- Skip release-train PRs (`development` into `master`); their commits are
  already in the log.
- Per PR: `gh pr view <N> --json number,title,author,body`
- Companion PRs: references in the body to other repos
  (`agroportal/<repo>#N`, PR URLs, "Depends on ...").

## 3. Collect backend-only changes

Notes cover the whole platform. List PRs merged between the previous and the
target `publishedAt`, on any base branch, in `ontologies_linked_data`,
`ontologies_api`, `ncbo_cron`, `goo` and `ontologies_api_ruby_client`:

    gh pr list -R agroportal/<repo> --state merged --search "merged:<from>..<to>" --json number,title,author,url,baseRefName

Drop the companions found in step 2. Ask which of the rest shipped with this
release.

## 4. Write

```
# AgroPortal v3.6.0

## Added

- Federated portals management in Site Administration #1273 (@maboukerfa)
- Add support for Crop Ontology TDv5 (XLSX) submissions #1256, https://github.com/agroportal/ontologies_linked_data/pull/252, https://github.com/agroportal/ontologies_api/pull/186 (@WailKouicemm)

## Changed

- Synonyms as compact chips #1271 (@maboukerfa)

## Fixed

- Ontology page overflowing on phones #1278 (@maboukerfa)
- definitions.ttl kept after archiving https://github.com/agroportal/ontologies_linked_data/pull/256 (@maboukerfa)

## Removed

- $PORTALS_INSTANCES configuration #1269 (@maboukerfa)
```

- Sections in this order; omit empty ones.
- One line per user-visible change. A UI PR and its companions share a line.
- Wording: what users see, short, no type prefix, no period.
  - Added: the new capability.
  - Changed: the new behavior.
  - Fixed: the symptom that is gone ("Ontology page overflowing on phones").
  - Removed: what is gone.
- References: `#N` for this repo first, then full URLs of other repos' PRs,
  comma-separated.
- Authors: `(@login)`; every distinct author of the line's PRs, `(@a, @b)`.
- Leave out ci, docs, test, build, chore, refactor and style changes unless
  users notice them.
- Say so when deployed portals must change their config.

## 5. Publish

Show the draft and wait for approval. Then write it to a file and run:

    gh release edit <tag> -R agroportal/ontoportal_web_ui --notes-file <file>

Only the body changes; keep the release name `vX.Y.Z`. Editing doesn't
rebuild the Docker image: `docker-image.yml` runs on `published` only.
