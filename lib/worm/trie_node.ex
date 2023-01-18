defmodule Worm.TrieNode do
  alias Worm.{Bitmap, Leaf, TrieNode}

  defstruct kind: nil,
            leftmost: nil,
            rightmost: nil,
            bitmap: Bitmap.new()

  def new(:root, %Leaf{} = leaf) do
    %__MODULE__{
      kind: :root,
      leftmost: leaf,
      rightmost: leaf
    }
  end

  def new(:leaf, %Leaf{} = leaf) do
    %__MODULE__{
      kind: :leaf,
      leftmost: leaf,
      rightmost: leaf
    }
  end

  def new(:internal, leaf) do
    %__MODULE__{
      kind: :internal,
      leftmost: leaf,
      rightmost: leaf
    }
  end

  def size(%__MODULE__{} = trie_node) do
    sum_size(trie_node.leftmost, trie_node.rightmost, 0)
  end

  defp sum_size(leaf, rightmost, total) do
    total = total + Leaf.size(leaf)

    if leaf == rightmost do
      total
    else
      sum_size(Leaf.right(leaf), rightmost, total)
    end
  end

  def update(%TrieNode{} = tn, %Leaf{} = leaf) do
    right_anc = Leaf.anchor(tn.rightmost)
    left_anc = Leaf.anchor(tn.leftmost)
    this_anc = Leaf.anchor(leaf)

    # IO.inspect(
    #   [
    #     right_anc: right_anc,
    #     left_anc: left_anc,
    #     this_anc: this_anc
    #   ],
    #   label: :trie_node_update_anchors
    # )

    cond do
      this_anc < left_anc ->
        put_leftmost(tn, leaf)

      this_anc > right_anc ->
        put_rightmost(tn, leaf)

      true ->
        # this_anc is in the middle of the leftmost and rightmost.
        # we do not want to point to it.
        tn
    end
  end

  def put_rightmost(tn, leaf) do
    %__MODULE__{tn | rightmost: leaf}
  end

  def put_leftmost(tn, leaf) do
    %__MODULE__{tn | leftmost: leaf}
  end

  def key(%TrieNode{kind: :leaf, leftmost: %Leaf{} = leaf}) do
    Leaf.first_key(leaf)
  end

  def key(%TrieNode{kind: :root, leftmost: %Leaf{} = leaf}) do
    Leaf.first_key(leaf)
  end

  def insert_bitmap(%TrieNode{} = tn, prefix, key) do
    if not String.starts_with?(key, prefix) do
      raise "invalid insert_bitmap keys - expected prefix: #{inspect(prefix)} to be a" <>
              " prefix of key: #{inspect(key)}"
    end

    case String.replace(key, prefix, "", global: false) do
      <<byte, _rest::binary>> ->
        bm = Bitmap.set(tn.bitmap, byte)
        %TrieNode{tn | bitmap: bm}

      <<>> ->
        tn
    end
  end
end
