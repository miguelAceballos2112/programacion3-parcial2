defmodule Terreno do
  @moduledoc """
  Tipo de casilla definido en `terrenos.csv`.

  * `simbolo`     - carácter que aparece en `edificio.txt` (por ejemplo `"."`).
  * `nombre`      - nombre legible (`"pasillo"`).
  * `transitable` - `true` si el robot puede entrar (`si` en el CSV), `false` si no (`no`).
  * `costo`       - energía que consume entrar a la casilla (entero no negativo).
  """

  defstruct simbolo: nil, nombre: nil, transitable: false, costo: 0

  @typedoc "Tipo de casilla leído de `terrenos.csv`."
  @type t :: %__MODULE__{
          simbolo: String.t(),
          nombre: String.t(),
          transitable: boolean(),
          costo: non_neg_integer()
        }
end
