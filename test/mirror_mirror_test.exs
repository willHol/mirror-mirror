defmodule MirrorMirrorTest do
  use ExUnit.Case
  doctest MirrorMirror

  test "greets the world" do
    assert MirrorMirror.hello() == :world
  end
end
