defmodule Worm.Leaf do
  alias Worm.Leaf

  defstruct [:table]

  def new do
    table =
      :ets.new(nil, [:public, :ordered_set, read_concurrency: true, write_concurrency: true])

    leaf = %Leaf{table: table}

    metadata = [
      left: nil,
      right: nil,
      anchor: nil
    ]

    _ = :ets.insert(table, metadata)
    leaf
  end

  def size(%Leaf{table: table}) do
    :ets.info(table, :size) - 3
  end

  def left(leaf), do: do_get(table(leaf), :left)
  def right(leaf), do: do_get(table(leaf), :right)

  def put_left(nil, _) do
    :nothing
  end

  def put_left(leaf, %Leaf{} = left) do
    do_put(table(leaf), :left, left)
  end

  def put_left(leaf, nil) do
    do_put(table(leaf), :left, nil)
  end

  def put_right(nil, _) do
    :nothing
  end

  def put_right(leaf, %Leaf{} = right) do
    do_put(table(leaf), :right, right)
  end

  def put_right(leaf, nil) do
    do_put(table(leaf), :right, nil)
  end

  def split(%Leaf{} = this_leaf) do
    # move the second half of the items from this_leaf to the new_leaf.
    split_at = size(this_leaf) - 1
    list = to_list(this_leaf)
    {_first_half, second_half} = Enum.split(list, split_at)

    new_leaf =
      Enum.reduce(second_half, new(), fn {key, val}, new_leaf ->
        :ok = put_kv(new_leaf, key, val)
        :deleted = delete_kv(this_leaf, key)
        new_leaf
      end)

    # remove the second half from this_leaf

    right_leaf = right(this_leaf)

    # insert the new_leaf into the leaf list by:
    # 1) set new_leaf.left to this_leaf
    # 2) set new_leaf.right to right_leaf
    # 3) set this_leaf.right to new_leaf
    # 4) set right_leaf.left to this_leaf

    _ = put_left(new_leaf, this_leaf)
    _ = put_right(new_leaf, right_leaf)
    _ = put_right(this_leaf, new_leaf)
    _ = put_left(right_leaf, this_leaf)

    {this_leaf, new_leaf}
  end

  def put_anchor(leaf, key) do
    do_put(table(leaf), :anchor, key)
  end

  def put_kv(leaf, key, val) do
    :ok = do_put(table(leaf), key, val)

    if anchor(leaf) == nil do
      :ok = put_anchor(leaf, key)
    end

    :ok
  end

  def first_key(leaf) do
    :ets.next(table(leaf), "")
  end

  def get_kv(leaf, key) do
    do_get(table(leaf), key, nil)
  end

  def fetch_kv(leaf, key) do
    do_fetch(table(leaf), key)
  end

  def find_target(%Leaf{} = leaf, key) do
    anc = anchor(leaf)

    cond do
      anc == key ->
        # the anchor is our key. we found the target.
        leaf

      anc < key ->
        # 1) the anchor is less than our key so we need to check the leaf to the right.
        # 2) if the leaf to the right is nil then we have found our target.
        # 3) if the anchor of the leaf to the right is less than our anchor we need to go to step 1
        find_target_right(leaf, key, right(leaf))

      anc > key ->
        find_target_left(left(leaf), key, leaf)
        # 1) the anchor is greater than our key so we need to check the leaf to the left.
        # 2) if the leaf to the left is nil then there is no target.
        # 3) if the anchor of the leaf to the right is less than our anchor we need to go to step 1
    end
  end

  defp find_target_left(nil, _key, right) do
    # when moving left if there is no leaf then there is no target
    right
  end

  defp find_target_left(%Leaf{} = leaf, key, _right) do
    # when moving left if the left leaf's anchor is less than or equal to our key we have found our target.

    if anchor(leaf) <= key do
      # the anchor indicates that the key could be in this leaf.
      {:ok, leaf}
    else
      find_target_left(left(leaf), key, leaf)
    end
  end

  defp find_target_right(%Leaf{} = target, _key, nil) do
    # moving right if there is no leaf then the previous leaf (`target` here) is the target
    target
  end

  defp find_target_right(%Leaf{} = left, key, %Leaf{} = right) do
    right_anc = anchor(right)

    if right_anc <= key do
      even_more_right = right(right)
      find_target_right(right, key, even_more_right)
    else
      left
    end
  end

  def delete_kv(leaf, key) do
    case fetch_kv(leaf, key) do
      {:ok, _} ->
        :ets.delete(table(leaf), key)
        :deleted

      :error ->
        :not_found
    end
  end

  defp table(%Leaf{table: table}), do: table

  defp do_get(tab, key, default \\ nil) do
    case do_fetch(tab, key) do
      :error -> default
      {:ok, val} -> val
    end
  end

  defp do_fetch(tab, key) do
    case :ets.lookup(tab, key) do
      [] -> :error
      [{_, val}] -> {:ok, val}
    end
  end

  defp do_put(tab, key, val) do
    _ = :ets.insert(tab, {key, val})
    :ok
  end

  def anchor(nil) do
    nil
  end

  def anchor(leaf) do
    do_get(table(leaf), :anchor)
  end

  def to_list(leaf) do
    leaf
    |> table()
    |> :ets.tab2list()
    |> Enum.filter(fn
      {k, _v} when k in [:left, :right, :anchor] -> false
      _ -> true
    end)
  end

  defimpl Inspect do
    def inspect(leaf, _opts) do
      anc = Leaf.anchor(leaf)
      items = Leaf.to_list(leaf)
      "#Leaf<anchor: #{inspect(anc)}, items: #{inspect(items)}>"
    rescue
      ArgumentError ->
        "#Leaf<:dead:>"
    end
  end
end
