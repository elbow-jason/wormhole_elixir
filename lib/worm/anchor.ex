# defmodule Worm.Anchor do
#   @moduledoc """
#   ## Anchor Conditions

#   - The Ordering Condition: `node_a_key` < `anchor_key` <= `node_b_key`, where `node_a_key`
#     represents any key in the node (`node_a`) immediately left of `node_b`, and
#     `node_b_key` represents any key in `node_b`. If `node_b` is the leftmost node in the
#     LeafList, the condition is `anchor_key` <= `node_b_key`.

#   - The Prefix Condition: An anchor key cannot be a prefix of another anchor key
#   """

#   alias Worm.Anchor

#   defstruct [:key, :mark]

#   def compare(%Anchor{} = a, %Anchor{} = b) do
#     cond do
#       a.key > b
#     end
#   end
# end
