defmodule Tarea do
  @moduledoc """
  Tarea del proyecto leída de `tareas.csv` (`id;duracion;plazo;dependencias`).

  `dependencias` es la lista de IDs de las que depende (`[]` cuando el CSV trae `-`).
  El lector conserva los valores tal como vienen (incluso duplicados, no positivos o
  no enteros) para que `ValidadorTareas` pueda reportarlos con su línea.
  """

  defstruct id: nil, duracion: 0, plazo: 0, dependencias: []

  @typedoc "Tarea del proyecto leída de `tareas.csv`."
  @type t :: %__MODULE__{
          id: String.t(),
          duracion: integer(),
          plazo: integer(),
          dependencias: [String.t()]
        }

  def crear(id, duracion, plazo, dependencias) do
    %Tarea{
      id: id,
      duracion: duracion,
      plazo: plazo,
      dependencias: dependencias
    }
  end
end
