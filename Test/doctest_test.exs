defmodule DoctestTest do
  @moduledoc """
  Ejecuta como pruebas los ejemplos `iex>` de la documentación (doctests), para que
  la documentación nunca quede desactualizada respecto al código.
  """
  use ExUnit.Case, async: true

  doctest Recorrido
  doctest Plan
  doctest Lector
  doctest Salida
  doctest Svg
end
