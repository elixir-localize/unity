# Credo configuration for Unity.
#
# Mirrors the Localize policy: strict, with `Design.AliasUsage` disabled.
# Unit parsing and conversion code fully qualifies many calls because
# module names such as `Localize.Unit` and `Unity.Unit` read more clearly
# at the call site than an alias, and because trailing segments such as
# `Unit`, `Parser` and `List` shadow other modules when aliased. Alias
# submodules opportunistically where the trailing segment does not clash,
# never as a bulk conversion.
%{
  configs: [
    %{
      name: "default",
      strict: true,
      files: %{
        included: ["lib/", "test/"]
      },
      checks: %{
        disabled: [
          {Credo.Check.Design.AliasUsage, []}
        ]
      }
    }
  ]
}
