defmodule Recorrido do
  @moduledoc """
  Recorrido simple del robot desde S hasta M.

  - `posiciones`: lista de coordenadas `{fila, columna}`, de S a M.
  - `energia`: energía consumida (la casilla inicial no consume).
  """

  @enforce_keys [:posiciones, :energia]
  defstruct [:posiciones, :energia]

  @doc """
  Cantidad de movimientos del recorrido (posiciones visitadas menos uno).
  """
  def movimientos(%Recorrido{posiciones: posiciones}), do: length(posiciones) - 1
end
