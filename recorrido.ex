defmodule Recorrido do
  @moduledoc """
  Recorrido simple del robot desde `S` hasta `M`.

  * `posiciones` - lista de `{fila, columna}` en orden, desde el inicio hasta la meta.
  * `energia`    - energía total consumida (la casilla inicial no consume).
  """

  defstruct posiciones: [], energia: 0

  @typedoc "Coordenada `{fila, columna}` con origen en 0."
  @type posicion :: {non_neg_integer(), non_neg_integer()}

  @typedoc "Recorrido simple con sus posiciones y la energía consumida."
  @type t :: %__MODULE__{posiciones: [posicion()], energia: non_neg_integer()}

  @doc """
  Número de movimientos: una posición menos que la cantidad de casillas visitadas.

  ## Ejemplos

      iex> Recorrido.movimientos(%Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}]})
      2

      iex> Recorrido.movimientos(%Recorrido{})
      0
  """
  @spec movimientos(t()) :: non_neg_integer()
  def movimientos(%__MODULE__{posiciones: []}), do: 0
  def movimientos(%__MODULE__{posiciones: [_inicio | resto]}), do: length(resto)
end
