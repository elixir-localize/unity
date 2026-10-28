# TODO

Work planned for unity, the library, its REPL and its command-line escript.

## Open

* [ ] **Format the forward value with `-e` and `-o`** — the default and verbose formats apply them only to the reciprocal line. `-o` hands its format to `:io_lib.format/2`, so `%g` keeps trailing zeros and `%d` raises on a float, where `Unity.Formatter` should return an error.

* [ ] **Resolve the bundled GNU units file at runtime** — `Unity.GnuUnitsImporter` reads `Application.app_dir/2` into `@bundled_path` at compile time, so a release run from another path looks for the build machine's file.

* [ ] **Make the command line's error paths testable** — `Unity.CLI` halts the VM on an error, so no test can exercise an error path in process.

* [ ] **Read plural unit names in GNU definitions** — GNU resolves `miles`, `days` and `ustablespoons` by stripping the plural, which `Unity.GnuUnitsImporter.Resolver` does not, so `marathon 26 miles + 385 yards`, `lunarmonth` and `eggvolume` are skipped, with every other definition written in the plural.

* [ ] **Take the resolver's state out of the process dictionary** — `Unity.GnuUnitsImporter.Resolver` keeps its environment, cache and prefix tables in `Process.put/2` and `Process.get/1`; pass them as an argument instead.

* [ ] **Raise test coverage to the 90% that `mix test --cover` requires** — coverage is 45% (the REPL 2%, the command line 62%), so the lint row runs `mix test` without `--cover`, unlike the reference workflow.

## In progress

* [ ] **Release the escript fixes** — require `localize ~> 1.4`, update `mix.lock`, and add a CI step that builds the escript with `MIX_ENV=prod` and runs a conversion. Localize 1.4.3 reads its data inside an escript (elixir-localize/localize#58); the requirement, the lock and the CI step landed on 2026-10-28, the Release Review and the release remain.

## Done

* [x] **Resolve a sum in a GNU definition as a sum** — the resolver splits a value at `+` and `-` outside parentheses and adds terms of one dimension, where it multiplied them; `smoot` is 1.7018 meters again. 2026-10-28, v1.2.0.
