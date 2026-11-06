# API Versioning Policy

## Current version

The current API version is `v1`. All application API endpoints are available
under `/api/v1`.

The Sidekiq Web UI (`/sidekiq`) and Rails health check (`/up`) remain outside API versioning.

## Introducing a new version

A new version such as `v2` is introduced only when a breaking API change is required. Backward-compatible changes remain in the existing version.

## Deprecating an old version

An existing API version remains supported while clients migrate to the new version. Before retirement:

1. Announce the deprecation to API consumers.
2. Provide migration guidance and a reasonable transition period.
3. Monitor usage of the old version.
4. Retire it after clients have migrated and the announced support period
   has ended.
