defmodule Worm do
  @moduledoc """
  Documentation for `Worm`.
  """

  alias Worm.{Bitmap, Leaf, TrieNode}

  defstruct ht: %{},
            max_anchor_len: 0,
            max_leaf_size: 4

  def new(max_leaf_size \\ 128) do
    leaf = Leaf.new()

    %Worm{
      max_leaf_size: max_leaf_size,
      # the only prefix in the ht is 0 bytes long
      max_anchor_len: 0,
      # the leftmost leaf that is empty and whose key is ""
      ht: %{"" => TrieNode.new(:root, leaf)}
    }
  end

  def delete(%Worm{} = worm, key) do
    lpm = longest_prefix_match(worm, key)
    {_node, anchored_leaf} = lookup_leaf(worm, key, lpm)
    leaf = Leaf.find_target(anchored_leaf, key)

    case Leaf.delete_kv(leaf, key) do
      :deleted ->
        if Leaf.size(leaf) == 0 do
          update_deleted(worm, leaf)
        else
          worm
        end

      :not_found ->
        # nothing changed so nothing to do
        worm
    end
  end

  def update_deleted(worm, leaf) do
    # extract the leaf from the doubly linked list
    left = Leaf.left(leaf)
    right = Leaf.right(leaf)
    anchor = Leaf.anchor(leaf)

    # update the node
    case Map.get(worm.ht, anchor) || Map.get(worm.ht, "") do
      %TrieNode{kind: :root, leftmost: ^leaf, rightmost: ^leaf} ->
        # empty self referential root node. Do we want to delete this node?
        worm

      %TrieNode{kind: :root, leftmost: ^leaf} = tn ->
        _ = Leaf.put_right(left, right)
        _ = Leaf.put_left(right, left)
        tn = TrieNode.put_leftmost(tn, right)
        update_deleted_ht(worm, tn, "")

      %TrieNode{kind: :root, rightmost: ^leaf} = tn ->
        _ = Leaf.put_right(left, right)
        _ = Leaf.put_left(right, left)
        tn = TrieNode.put_rightmost(tn, left)
        update_deleted_ht(worm, tn, "")

      %TrieNode{leftmost: ^leaf} = tn ->
        _ = Leaf.put_right(left, right)
        _ = Leaf.put_left(right, left)
        tn = TrieNode.put_leftmost(tn, right)
        anchor = Leaf.anchor(right)
        update_deleted_ht(worm, tn, anchor)

      %TrieNode{rightmost: ^leaf} = tn ->
        _ = Leaf.put_right(left, right)
        _ = Leaf.put_left(right, left)
        tn = TrieNode.put_rightmost(tn, left)
        anchor = Leaf.anchor(left)
        update_deleted_ht(worm, tn, anchor)

      %TrieNode{} ->
        worm

      nil ->
        worm
    end
  end

  defp update_deleted_ht(worm, _tn, nil) do
    worm
  end

  defp update_deleted_ht(worm, tn, anchor) do
    root = Map.fetch!(worm.ht, "")

    if tn.leftmost == root.leftmost && tn.rightmost == root.rightmost do
      new_root = %TrieNode{tn | kind: :root}

      ht =
        worm.ht
        |> Map.delete(anchor)
        |> Map.delete("")
        |> Map.put("", new_root)

      %Worm{worm | ht: ht}
    else
      %Worm{worm | ht: Map.put(worm.ht, anchor, tn)}
    end
  end

  def fetch(%Worm{} = worm, key) do
    lpm = longest_prefix_match(worm, key)
    {_node, leaf} = lookup_leaf(worm, key, lpm)

    with(
      target <- Leaf.find_target(leaf, key),
      {:ok, value} <- Leaf.fetch_kv(target, key)
    ) do
      {:ok, value}
    end
  end

  def put(%Worm{} = worm, key, val) do
    lpm = longest_prefix_match(worm, key)
    {node, anchored_leaf} = lookup_leaf(worm, key, lpm)
    leaf = Leaf.find_target(anchored_leaf, key)

    worm =
      if Leaf.size(leaf) >= worm.max_leaf_size do
        {leaf, new_leaf} = Leaf.split(leaf)
        new_leaf_anchor = Leaf.anchor(new_leaf)

        if key >= new_leaf_anchor do
          :ok = Leaf.put_kv(new_leaf, key, val)
        else
          :ok = Leaf.put_kv(leaf, key, val)
        end

        worm = add_leaf(worm, new_leaf)
        worm
      else
        :ok = Leaf.put_kv(leaf, key, val)
        worm
      end

    case node do
      nil ->
        worm

      %TrieNode{} ->
        node = Map.fetch!(worm.ht, lpm)
        node = TrieNode.insert_bitmap(node, lpm, key)

        %Worm{
          worm
          | ht: Map.put(worm.ht, lpm, node)
        }
    end
  end

  def add_leaf(%Worm{ht: ht} = worm, %Leaf{} = leaf) do
    # NOTE: don't forget to adjust anchor length when adding a new leaf

    # STEPS
    # figure out if this leaf should be added to the ht
    # IO.inspect(leaf, label: :add_leaf)
    anchor = Leaf.anchor(leaf)

    [_ | prefixes] = prefixes(anchor)

    ht =
      case Map.get(ht, anchor) do
        nil ->
          # IO.inspect(leaf, label: :added_new_leaf)
          new_node = TrieNode.new(:leaf, leaf)
          Map.put(ht, anchor, new_node)

        %TrieNode{kind: :leaf} = node ->
          raise "already a :leaf node - node: #{inspect(node)}, leaf: #{inspect(leaf)}"

        %TrieNode{kind: :internal} = node ->
          raise "already a :internal node - node: #{inspect(node)}, leaf: #{inspect(leaf)}"
      end

    # IO.inspect(ht, label: :ht_after_anchor_key)

    ht =
      Enum.reduce(prefixes, ht, fn prefix, ht ->
        trie_node =
          ht
          |> Map.get_lazy(prefix, fn -> TrieNode.new(:internal, leaf) end)
          |> TrieNode.update(leaf)

        Map.put(ht, prefix, trie_node)
      end)

    %Worm{worm | ht: ht}
  end

  defp lookup_leaf(%Worm{} = worm, key, lpm) do
    # IO.inspect(key, label: :lookup_leaf_key)
    # IO.inspect(lpm, label: :lookup_leaf_lpm)
    %TrieNode{} = node = Map.fetch!(worm.ht, lpm)
    # IO.inspect(node, label: :lookup_leaf_node)

    cond do
      node.kind in [:leaf, :root] ->
        # IO.inspect(node, label: :lookup_leaf_node_was_leaf)
        {node, node.leftmost}

      byte_size(TrieNode.key(node)) == byte_size(key) ->
        IO.puts("node key size was key size")

        if key < Leaf.anchor(node.leftmost) do
          # we go to the left of our current node
          # IO.inspect(ret,
          #   label: "key was before leaf anchor - returning Leaf.leaf(leaf)"
          # )
          {nil, Leaf.left(node.leftmost)}
        else
          {node, node.leftmost}
        end

      true ->
        IO.puts("searching for sibling")
        node_key = TrieNode.key(node)
        node_key_len = byte_size(node_key)
        <<missing>> = String.at(key, node_key_len)
        # find_one_sibling
        sibling =
          node.bitmap
          |> Bitmap.list_above(missing)
          |> List.first() || raise "nope"

        sibling_key = node_key <> <<sibling>>
        child = Map.fetch!(worm.ht, sibling_key)

        if child.kind == :external do
          if sibling > missing do
            child.leftmost
          else
            child
          end
        else
          if sibling > missing do
            Leaf.left(child.leftmost)
          else
            Leaf.left(child.rightmost)
          end
        end
    end
  end

  def prefixes(key) do
    [key | do_prefixes(key)]
  end

  defp do_prefixes("") do
    []
  end

  defp do_prefixes(key) do
    plen = byte_size(key) - 1
    prefix = binary_part(key, 0, plen)
    [prefix | do_prefixes(prefix)]
  end

  @doc """
  Search the hashtable for the longest matching prefix of the given key.

  This function implements binary search by length of the key (or the Worm's :max_len).
  """
  def longest_prefix_match(%Worm{} = worm, key) do
    # IO.inspect(Map.keys(worm.ht), label: :ht_keys_during_longest_prefix_match)
    do_lpm(worm.ht, worm.max_anchor_len, key)
  end

  defp do_lpm(_, _, "") do
    # IO.inspect("", label: :empty_key_in_lpm)
    ""
  end

  defp do_lpm(ht, _max_anchor_len, key) when byte_size(key) == 1 do
    if Map.has_key?(ht, key) do
      # IO.inspect(key, label: :len_one_key_in_lpm)
      key
    else
      # IO.inspect(key, label: :len_zero_key_in_lpm)
      ""
    end
  end

  defp do_lpm(ht, max_anchor_len, key) do
    # IO.inspect(Map.keys(ht), label: :ht_keys_in_lpm)
    # m and n defined here for clarity's sake.
    m = 0
    n = min(max_anchor_len, byte_size(key)) + 1
    do_longest_prefix_match(ht, key, m, n)
  end

  defp do_longest_prefix_match(ht, key, m, n) when m + 1 < n do
    prefix_len = div(m + n, 2)
    prefix = binary_part(key, 0, prefix_len)

    cond do
      prefix_len == 0 ->
        # IO.inspect(prefix, label: :lpm_candidate_len_was_zero)
        ""

      Map.has_key?(ht, prefix) ->
        do_longest_prefix_match(ht, key, prefix_len, n)

      true ->
        do_longest_prefix_match(ht, key, m, prefix_len)
    end
  end

  defp do_longest_prefix_match(_ht, key, m, _n) do
    # this might be off by 1?
    # IO.inspect(binary_part(key, 0, m), label: :lpm_out)
    binary_part(key, 0, m)
  end

  def to_list(worm) do
    worm.ht
    |> Map.fetch!("")
    |> case do
      %TrieNode{leftmost: l} -> l
    end
    |> do_to_list()
    |> List.flatten()
  end

  defp do_to_list(nil) do
    []
  end

  defp do_to_list(%Leaf{} = leaf) do
    [Leaf.to_list(leaf), do_to_list(Leaf.right(leaf))]
  end
end
