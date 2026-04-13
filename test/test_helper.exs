Localize.put_default_locale(:en)

# Diagnostic: print literal allocator state before tests run
if System.get_env("CI") do
  [{:instance, 0, sections}] = :erlang.system_info({:allocator, :literal_alloc})
  {_, options} = List.keyfind(sections, :options, 0)
  {_, mbcs} = List.keyfind(sections, :mbcs, 0)
  IO.puts("\n=== literal_alloc (in test BEAM) ===")
  IO.puts("  options: #{inspect(Keyword.take(options, [:mmbcs, :smbcs, :lmbcs, :sbct]))}")
  IO.puts("  mbcs: #{inspect(mbcs)}")

  mmap_info = :erlang.system_info({:allocator, :erts_mmap})
  IO.puts("  erts_mmap: #{inspect(mmap_info, limit: :infinity, width: 200)}")
  IO.puts("===\n")
end

ExUnit.start(exclude: [:integration])
