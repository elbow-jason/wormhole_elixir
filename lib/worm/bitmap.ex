defmodule Worm.Bitmap do
  @moduledoc """
  A 256-bit bitmap stored in an integer.
  """
  alias Worm.Bitmap
  import Bitwise

  defstruct bits: 0

  def new do
    %Bitmap{bits: 0}
  end

  defguard is_byte(b) when b in 0..255

  def set(%Bitmap{bits: bits} = bitmap, byte) when is_byte(byte) do
    %Bitmap{bitmap | bits: bor(bits, 1 <<< byte)}
  end

  def unset(%Bitmap{bits: bits} = bitmap, byte) when is_byte(byte) do
    mask = bnot(1 <<< byte)
    %Bitmap{bitmap | bits: band(bits, mask)}
  end

  def contains?(%Bitmap{bits: bits}, byte) when is_byte(byte) do
    do_contains?(bits, byte)
  end

  def to_list(%Bitmap{bits: bits}) do
    do_to_list(bits, -1, -1, 255, [])
  end

  def list_above(%Bitmap{bits: bits}, byte) do
    do_to_list(bits, (byte + 1)..255)
  end

  def list_below(%Bitmap{bits: bits}, byte) when is_byte(byte) do
    do_to_list(bits, (byte - 1)..0)
  end

  defp do_contains?(bits, byte) do
    mask = 1 <<< byte
    band(bits, mask) > 0
  end

  defp do_to_list(bits, lo..hi) when lo <= hi do
    do_to_list(bits, lo - 1, -1, hi, [])
  end

  defp do_to_list(bits, hi..lo) when lo < hi do
    do_to_list(bits, hi + 1, +1, lo, [])
  end

  defp do_to_list(_bits, limit, _diff, byte, members) when byte == limit do
    members
  end

  defp do_to_list(bits, limit, diff, byte, members) do
    members =
      if do_contains?(bits, byte) do
        [byte | members]
      else
        members
      end

    do_to_list(bits, limit, diff, byte + diff, members)
  end

  defimpl Inspect do
    def inspect(bitmap, _opts) do
      items = Bitmap.to_list(bitmap)
      "#Worm.Bitmap<#{inspect(items)}>"
    end
  end
end
