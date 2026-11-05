defmodule Tarea do
  @moduledoc """
  Tarea del proyecto leída de `tareas.csv` (`id;duracion;plazo;dependencias`).

  `dependencias` es la lista de IDs de las que depende (`[]` cuando el CSV trae `-`).
  El parser conserva los valores tal como vienen (incluso duplicados o no positivos)
  para que el validador pueda reportarlos con su línea.
  """

  defstruct id: nil, duracion: 0, plazo: 0, dependencias: []

  @typedoc "Tarea del proyecto leída de `tareas.csv`."
  @type t :: %__MODULE__{
          id: String.t(),
          duracion: integer(),
          plazo: integer(),
          dependencias: [String.t()]
        }
end
