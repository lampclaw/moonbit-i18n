# Repository agent instructions

## Collaboration response format

For every user question, first restate the task in collaboration-friendly
Chinese and English and add one sentence explaining why it was restated that
way. Then answer or execute the original request. Treat `继续`, `go ahead`,
`do it`, and `按这个来` as approval to continue without asking again.

Before planning or changing a public API, authoring format, MF2 profile,
catalog contract, runtime, generator, CLI, or supported target:

1. Read `docs/roadmap.mbt.md` and `docs/mf2-profile.mbt.md` completely.
2. Identify the roadmap milestone and acceptance gate served by the change.
3. Preserve the MoonBit package and target boundaries defined by the roadmap.
4. Update `docs/roadmap.mbt.md` and `docs/roadmap.zh-CN.mbt.md` together when
   a decision changes; keep the matching README and changelog statements
   synchronized.
5. Do not claim planned behavior as implemented or Unicode MF2 conformance
   beyond the exact profile and tests shipped by the release.

Bug fixes that do not change a public contract still follow the current
profile, compatibility, security, and quality gates.
