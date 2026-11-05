defmodule Terreno do
  @moduledoc """
  Tipo de casilla del edificio, definido en `terrenos.csv`.

  ## Información

  - **Problema:** 1 – Robot de rescate
  - **Rol:** 1 – Algoritmos y Streams
  """

  @enforce_keys [:simbolo, :nombre, :transitable, :costo]
  defstruct [:simbolo, :nombre, :transitable, :costo]

  @doc """
  Convierte una lista de terrenos en un mapa `%{simbolo => %Terreno{}}`.

  Así el robot consulta los símbolos y costos desde la tabla de terrenos y no
  desde el código de la búsqueda.

  ## Parámetros

  - `terrenos`: lista de `%Terreno{}`. El campo `transitable` debe ser booleano
    (quien lea el CSV convierte `"si"`/`"no"` en `true`/`false`).

  ## Ejemplo

      Terreno.indexar([%Terreno{simbolo: ".", nombre: "pasillo", transitable: true, costo: 1}])
      # => %{"." => %Terreno{...}}
  """
  def indexar(terrenos) do
    Enum.reduce(terrenos, %{}, fn %Terreno{simbolo: simbolo} = terreno, mapa ->
      Map.put(mapa, simbolo, terreno)
    end)
  end
end
