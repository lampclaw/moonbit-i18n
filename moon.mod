name = "lampclaw/i18n"

version = "0.1.0-rc.1"

preferred_target = "native"

source = "."

readme = "README.mbt.md"

repository = "https://github.com/lampclaw/moonbit-i18n"

license = "Apache-2.0"

keywords = [ "i18n", "localization", "messageformat", "mf2", "unicode" ]

description = "Typed internationalization, MF2 formatting, and catalog tooling for MoonBit"

import {
  "Milky2018/xml@0.4.0",
  "moonbitlang/x@0.4.49",
  "moonbitlang/parser@0.3.13",
  "moonbitlang/async@0.20.3",
}

options(
  exclude: [
    ".github/**",
    "_build/**",
    "examples/**",
    "moon.work",
    "benchmarks/**",
    "scripts/**",
    "tests/**",
    "AGENTS.md",
    "CONTRIBUTING.md",
    "docs/release-checklist.md",
    "**/*_test.mbt",
    "**/*_wbtest.mbt",
    "**/pkg.generated.mbti",
  ],
)
