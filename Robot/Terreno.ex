defmodule Terreno do
  @moduledoc """
  Tipo de casilla definido en `terrenos.csv`.

  * `simbolo`     - carácter que aparece en `edificio.txt` (por ejemplo `"."`).
  * `nombre`      - nombre legible (`"pasillo"`).
  * `transitable` - `true` si el robot puede entrar (`si` en el CSV), `false` si no (`no`).
  * `costo`       - energía que consume entrar a la casilla (entero no negativo).

  Si `transitable` o `costo` no se pueden convertir, el lector deja el texto original
  para que `ValidadorEdificio` lo reporte con su línea.
  """

  defstruct simbolo: nil, nombre: nil, transitable: false, costo: 0

  @typedoc "Tipo de casilla leído de `terrenos.csv`."
  @type t :: %__MODULE__{
          simbolo: String.t(),
          nombre: String.t(),
          transitable: boolean(),
          costo: non_neg_integer()
        }

  def crear(simbolo, nombre, transitable, costo) do
    %Terreno{
      simbolo: simbolo,
      nombre: nombre,
      transitable: transitable,
      costo: costo
    }
  end

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
