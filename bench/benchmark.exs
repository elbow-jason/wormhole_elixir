all_kvs = Enum.map(1..100_000, fn i -> {<<i::big-unsigned-integer-size(64)>>, i} end)

Benchee.run(%{
  "worm.put" => fn {kvs, _} -> Enum.reduce(kvs, Worm.new(), fn {k, v}, worm -> Worm.put(worm, k, v) end) end,
  "worm.fetch" => fn {kvs, worm} -> Enum.each(kvs, fn {k, _} -> Worm.fetch(worm, k) end) end,
  "worm.delete" => fn {kvs, worm} -> Enum.reduce(kvs, worm, fn {k, _}, worm -> Worm.delete(worm, k) end) end
},
before_scenario: fn kvs ->
  worm = Enum.reduce(kvs, Worm.new(), fn {k, v}, worm -> Worm.put(worm, k, v) end)
  {kvs, worm}
end,
inputs: %{
  "x10" => Enum.take(all_kvs, 10),
  "x100" => Enum.take(all_kvs, 100),
  "x1000" => Enum.take(all_kvs, 1000),
  "x10000" => Enum.take(all_kvs, 10000),
})
