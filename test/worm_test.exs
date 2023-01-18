defmodule WormTest do
  use ExUnit.Case
  doctest Worm
  alias Worm.TrieNode
  alias Worm.{Anchor, Leaf}
  # describe "prefixes/1" do
  #   test "works" do
  #     key = "jose"
  #     # assert Worm.prefixes(key) == ["jose", "jos", "jo", "j", ""]
  #   end
  # end

  describe "longest_prefix_match/2" do
    test "works for len 3 anchor" do
      worm = %Worm{
        max_anchor_len: 3,
        ht: %{
          "" => 120,
          "j" => 121,
          "jo" => 122,
          "jos" => 123
        }
      }

      assert Worm.longest_prefix_match(worm, "joseph") == "jos"
    end

    test "works for len 1 anchor" do
      worm = %Worm{
        max_anchor_len: 1,
        ht: %{
          "" => 120,
          "j" => 121
        }
      }

      assert Worm.longest_prefix_match(worm, "j") == "j"
    end

    test "works" do
      worm = %Worm{
        max_anchor_len: 6,
        ht: %{
          "" => 120,
          "j" => 121,
          "jo" => 122,
          "jos" => 123,
          "jose" => 124,
          "joster" => 125
        }
      }

      assert Worm.longest_prefix_match(worm, "joseph") == "jose"
    end
  end

  describe "remove/2" do
    test "does nothing for an empty worm tree" do
      w1 = Worm.new(4)
      node1 = Map.fetch!(w1.ht, "")
      w2 = Worm.delete(w1, "some_key")
      node2 = Map.fetch!(w2.ht, "")
      assert w1 == w2
      assert node1 == node2
      assert Leaf.to_list(node1.leftmost) == []
      assert Leaf.to_list(node1.rightmost) == []
    end

    test "does nothing for a missing key" do
      w1 = Worm.new(4)
      w1 = Worm.put(w1, "a", :a)
      node1 = Map.fetch!(w1.ht, "")
      assert Leaf.to_list(node1.leftmost) == [{"a", :a}]
      assert Leaf.to_list(node1.rightmost) == [{"a", :a}]
      w2 = Worm.delete(w1, "BLEP")
      node2 = Map.fetch!(w2.ht, "")
      assert node1 == node2
      assert Leaf.to_list(node2.leftmost) == [{"a", :a}]
      assert Leaf.to_list(node2.rightmost) == [{"a", :a}]
    end

    test "remove all keys from root" do
      kvs = %{"a" => :a, "b" => :b, "c" => :c, "d" => :d, "e" => :e, "f" => :f}
      w1 = Enum.reduce(kvs, Worm.new(4), fn {k, v}, worm -> Worm.put(worm, k, v) end)

      w2 = Worm.delete(w1, "a")
      w2 = Worm.delete(w2, "b")
      assert %{"" => root_node, "d" => d_node} = w2.ht
      # IO.inspect(root_node, label: :remove_all_keys_root_node)
      # IO.inspect(c_node, label: :remove_all_keys_c_node)
      assert TrieNode.size(root_node) == 4
      assert TrieNode.size(d_node) == 3

      assert Worm.to_list(w2) == [
               {"c", :c},
               {"d", :d},
               {"e", :e},
               {"f", :f}
             ]
    end
  end

  test "simple put and fetch works" do
    w = Worm.new(4)
    w = Worm.put(w, "hello", "world")
    assert Worm.fetch(w, "hello") == {:ok, "world"}
    assert Worm.fetch(w, "hello2") == :error
  end

  test "works after splitting leaves" do
    w = Worm.new(4)
    assert w.max_leaf_size == 4
    w = Worm.put(w, "b", :b)
    w = Worm.put(w, "c", :c)
    w = Worm.put(w, "d", :d)
    w = Worm.put(w, "e", :e)
    w = Worm.put(w, "f", :f)
    w = Worm.put(w, "g", :g)
    assert map_size(w.ht) == 2
    node1 = w.ht |> Map.fetch!("")
    node2 = w.ht |> Map.fetch!("e")

    assert Leaf.anchor(node1.leftmost) == "b"
    assert Leaf.anchor(node1.rightmost) == "e"
    # assert Leaf.left(node1.leftmost) == node1.leftmost
    assert node1.rightmost == node2.rightmost
    assert node1.rightmost == node2.leftmost
    assert Worm.fetch(w, "a") == :error
    assert Worm.fetch(w, "b") == {:ok, :b}
    assert Worm.fetch(w, "c") == {:ok, :c}
    assert Worm.fetch(w, "d") == {:ok, :d}
    assert Worm.fetch(w, "e") == {:ok, :e}
    assert Worm.fetch(w, "f") == {:ok, :f}
    assert Worm.fetch(w, "g") == {:ok, :g}
    assert Worm.fetch(w, "h") == :error
  end

  test "works with high key count" do
    kvs = Enum.map(1..40, fn i -> {<<i::big-unsigned-integer-size(16)>>, i} end)
    worm = Worm.new(4)

    worm2 =
      Enum.reduce(kvs, worm, fn {k, v}, acc ->
        acc2 = Worm.put(acc, k, v)

        case Worm.fetch(acc2, k) do
          {:ok, v} ->
            acc2

          :error ->
            worm_ins = inspect(worm)
            raise "what is this? #{inspect({k, v})} #{worm_ins}"
        end

        acc2
      end)

    assert assert map_size(worm2.ht) == 14
  end
end
