defmodule Worm.BitmapTest do
  use ExUnit.Case

  alias Worm.Bitmap

  describe "new/0" do
    test "works" do
      assert Bitmap.new() == %Bitmap{bits: 0}
    end
  end

  describe "set/2" do
    test "works" do
      bm = Bitmap.new()
      bm = Bitmap.set(bm, 0)
      assert bm.bits == 1
    end
  end

  describe "unset/2" do
    test "works" do
      bm = Bitmap.new()
      bm = Bitmap.set(bm, 0)
      assert Bitmap.contains?(bm, 0) == true
      bm = Bitmap.unset(bm, 0)
      assert Bitmap.contains?(bm, 0) == false
    end
  end

  describe "contains?/2" do
    test "works" do
      bm = Bitmap.new()
      bm = Bitmap.set(bm, 0)
      assert Bitmap.contains?(bm, 0) == true
      bm = Bitmap.unset(bm, 0)
      assert Bitmap.contains?(bm, 0) == false
    end
  end

  describe "to_list/1" do
    test "works" do
      bm =
        Bitmap.new()
        |> Bitmap.set(0)
        |> Bitmap.set(10)
        |> Bitmap.set(245)
        |> Bitmap.set(255)

      assert Bitmap.to_list(bm) == [0, 10, 245, 255]
    end
  end

  describe "list_above/2" do
    test "works" do
      bm =
        Bitmap.new()
        |> Bitmap.set(0)
        |> Bitmap.set(10)
        |> Bitmap.set(245)
        |> Bitmap.set(255)

      assert Bitmap.list_above(bm, 10) == [245, 255]
    end
  end

  describe "list_below/2" do
    test "works" do
      bm =
        Bitmap.new()
        |> Bitmap.set(0)
        |> Bitmap.set(10)
        |> Bitmap.set(245)
        |> Bitmap.set(255)

      assert Bitmap.list_below(bm, 245) == [10, 0]
    end
  end
end
