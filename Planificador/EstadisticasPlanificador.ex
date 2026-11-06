defmodule Planificador.Estadisticas do
  @moduledoc """
  Acumulador de la enumeración de planes.

  Guarda el total de planes, la penalización mínima y los planes que la alcanzan,
  en orden de aparición (el primero es el que se dibuja en el Gantt). Cada óptimo se
  guarda como `{id, plan}`, donde `id` es el consecutivo del plan en `planes.csv`. No
  guarda la lista de todos los planes.
  """

  defstruct total: 0, penalizacion_minima: nil, optimos: []

  # -----------------------------------
  # API pública
  # -----------------------------------

  @doc """
  Crea las estadísticas iniciales (sin planes).
  """
  def nuevo, do: %__MODULE__{}

  @doc """
  Incorpora un plan a las estadísticas.

  Recibe `(plan, estadisticas)` para poder usarse directamente como función
  receptora de `Planificador.generar_planes/3`:

      Planificador.generar_planes(tareas, Planificador.Estadisticas.nuevo(),
                                  &Planificador.Estadisticas.actualizar/2)

  El id del plan actual es `total + 1` antes de llamar a `actualizar/2`, el mismo
  consecutivo con el que se escribe en `planes.csv`.
  """
  def actualizar(%Plan{penalizacion: penalizacion} = plan, %__MODULE__{} = estadisticas) do
    entrada = {estadisticas.total + 1, plan}

    {minima, optimos} =
      mejorar(estadisticas.penalizacion_minima, estadisticas.optimos, penalizacion, entrada)

    %{
      estadisticas
      | total: estadisticas.total + 1,
        penalizacion_minima: minima,
        optimos: optimos
    }
  end

  @doc """
  Primer plan óptimo encontrado (o `nil` si no hay planes).
  """
  def primer_optimo(%__MODULE__{optimos: [{_id, primero} | _]}), do: primero
  def primer_optimo(%__MODULE__{}), do: nil

  # -----------------------------------
  # Funciones auxiliares privadas
  # -----------------------------------

  # Sin mínimo todavía: este es el primero.
  defp mejorar(nil, _optimos, valor, entrada), do: {valor, [entrada]}

  # Menor penalización: reemplaza la lista de óptimos.
  defp mejorar(minimo, _optimos, valor, entrada) when valor < minimo, do: {valor, [entrada]}

  # Empate: se conserva en orden de aparición.
  defp mejorar(minimo, optimos, valor, entrada) when valor == minimo,
    do: {minimo, optimos ++ [entrada]}

  # Mayor penalización: no cambia nada.
  defp mejorar(minimo, optimos, _valor, _entrada), do: {minimo, optimos}
end
