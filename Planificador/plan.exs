defmodule Plan do
  @moduledoc """
  Un orden válido de ejecución de las tareas.

  - `orden`: lista de IDs en el orden de ejecución.
  - `finalizaciones`: lista de `{id, inicio, fin}` (el Gantt necesita el inicio).
  - `penalizacion`: suma de `max(0, fin - plazo)` de todas las tareas.
  """

  @enforce_keys [:orden, :finalizaciones, :penalizacion]
  defstruct [:orden, :finalizaciones, :penalizacion]

  @doc """
  Duración total del proyecto: el fin de la última tarea (0 si no hay tareas).

  ## Ejemplo

      Plan.duracion_total(%Plan{orden: ["A"], finalizaciones: [{"A", 0, 3}], penalizacion: 0})
      # => 3
  """
  def duracion_total(%Plan{finalizaciones: []}), do: 0

  def duracion_total(%Plan{finalizaciones: finalizaciones}) do
    {_id, _inicio, fin} = List.last(finalizaciones)
    fin
  end
end
