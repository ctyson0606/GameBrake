# GOTCHAS

Version-bound traps. Every entry carries a date. Entries here may be deleted
without justification once the dependency they describe is gone.

Format:  ### <one-line trap>  `[YYYY-MM-DD]`

### `dotnet new sln` on SDK 10 produces GameBrake.slnx, not a .sln  `[2026-08-23]`

The XML solution format is the default from .NET 10. Tooling older than
VS 2022 17.13 or SDK 9.0.200 cannot open it. Nothing here is affected, since
the build runs through `dotnet` on SDK 10.0.400, but a search for
"GameBrake.sln" finds nothing and the absence looks like a missing file.
