// semantic-release config, run by .github/workflows/release.yml.

// Bump picked in the Run workflow form. "auto" lets the commits decide;
// "patch" releases 3.6.2 after 3.6.1 even when a feat landed.
const BUMP = process.env.RELEASE_BUMP;
const FORCED_BUMPS = ["patch", "minor", "major"];

// A rule without conditions matches every commit, so the default rules
// never run and every commit counts as BUMP.
const releaseRules = FORCED_BUMPS.includes(BUMP) ? [{ release: BUMP }] : undefined;

export default {
  branches: ["+([0-9])?(.{+([0-9]),x}).x", "master"],
  plugins: [
    ["@semantic-release/commit-analyzer", { preset: "conventionalcommits", releaseRules }],
    [
      "@semantic-release/release-notes-generator",
      {
        preset: "conventionalcommits",
        presetConfig: {
          types: [
            { type: "feat", section: "Added" },
            { type: "fix", section: "Fixed" },
            { type: "perf", section: "Changed" },
          ],
        },
      },
    ],
    [
      "@semantic-release/github",
      { successComment: false, failComment: false, releasedLabels: false },
    ],
  ],
};
