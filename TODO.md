# TODO

Work planned for unity, the library, its REPL and its command-line escript.

## Open

* [ ] **Format the forward value with `-e` and `-o`** — the default and verbose formats apply them only to the reciprocal line. `-o` hands its format to `:io_lib.format/2`, so `%g` keeps trailing zeros and `%d` raises on a float, where `Unity.Formatter` should return an error.

* [ ] **Resolve the bundled GNU units file at runtime** — `Unity.GnuUnitsImporter` reads `Application.app_dir/2` into `@bundled_path` at compile time, so a release run from another path looks for the build machine's file.

* [ ] **Make the command line's error paths testable** — `Unity.CLI` halts the VM on an error, so no test can exercise an error path in process.

* [ ] **Raise test coverage to the 90% that `mix test --cover` requires** — coverage is 45% (the REPL 2%, the command line 62%), so the lint row runs `mix test` without `--cover`, unlike the reference workflow.

## In progress

* [ ] **Release the escript fixes** — require `localize ~> 1.4`, update `mix.lock`, and add a CI step that builds the escript with `MIX_ENV=prod` and runs a conversion. Localize 1.4.3 reads its data inside an escript (elixir-localize/localize#58); the requirement, the lock and the CI step landed on 2026-10-28, the Release Review and the release remain.
