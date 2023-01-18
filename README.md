# Worm

This is a proof-of-concept for a wormhole tree.

## Concerns

This implementation of a wormhole tree uses :ets tables as leaves. Using :ets tables as leaves seriously limits its usefulness; the maximum number of :ets tables is finite and using many `Worm` trees may lead to :ets table exhaustion. However, using :ets made treating the leaves as pointer-like objects very easy. It is likely that a wormhole tree implementation without the usage of pointers is very inefficient.

Though, it is entirely possible to use a single :ets table for each tree's leaf list storing a leaf as a `{reference, BTree}` that is tracked via it's reference and updated by replacing the full BTree with each change. I did not bother attempting this implementation.
