# 0004 Use Melos Monorepo

## Context

SwanSport needs a single repository with one app and several shared packages.

## Decision

Use a Dart workspace and Melos to manage package bootstrap, analysis, formatting, tests, and future generation commands.

## Consequences

Package boundaries must stay explicit. Shared packages must not depend on the app.
