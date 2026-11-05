defmodule Plan do
  @moduledoc """
  Orden válido de ejecución de las tareas.

  * `orden`          - lista de IDs en el orden de ejecución.
  * `finalizaciones` - lista de `{id, inicio, fin}` en el mismo orden (el Gantt necesita el inicio).
  * `penalizacion`   - suma de `max(0, fin - plazo)` de todas las tareas.
  """

  defstruct orden: [], finalizaciones: [], penalizacion: 0

  @typedoc "Plan de ejecución con orden, finalizaciones `{id, inicio, fin}` y penalización."
  @type t :: %__MODULE__{
          orden: [String.t()],
          finalizaciones: [{String.t(), non_neg_integer(), non_neg_integer()}],
          penalizacion: non_neg_integer()
        }

  @doc """
  Tiempo total del proyecto: el mayor instante de finalización (0 si no hay tareas).

  ## Ejemplos

      iex> plan = %Plan{finalizaciones: [{"A", 0, 3}, {"B", 3, 5}]}
      iex> Plan.duracion_total(plan)
      5

      iex> Plan.duracion_total(%Plan{})
      0
  """
  @spec duracion_total(t()) :: non_neg_integer()
  def duracion_total(%__MODULE__{finalizaciones: finalizaciones}), do: mayor_fin(finalizaciones, 0)

  defp mayor_fin([], acumulado), do: acumulado
  defp mayor_fin([{_id, _inicio, fin} | resto], acumulado), do: mayor_fin(resto, max(fin, acumulado))
end
