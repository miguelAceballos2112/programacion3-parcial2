Code.require_file("recorrido.exs", __DIR__)

defmodule Robot.Estadisticas do
  @moduledoc """
  Acumulador de la búsqueda del robot.

  No guarda todos los recorridos: solo el total y los recorridos que empatan en
  el mínimo de movimientos y en el mínimo de energía. El primer elemento de cada
  lista de empates es el primero encontrado en el orden fijo arriba, derecha,
  abajo, izquierda (el que se dibuja en el SVG).
  """

  defstruct total: 0,
            min_movimientos: nil,
            menos_movimientos: [],
            min_energia: nil,
            menor_energia: []

  # -----------------------------------
  # API pública
  # -----------------------------------

  @doc """
  Crea las estadísticas iniciales (sin recorridos).
  """
  def nuevo, do: %__MODULE__{}

  @doc """
  Incorpora un recorrido a las estadísticas.

  Recibe `(recorrido, estadisticas)` para poder usarse directamente como función
  receptora de `Robot.buscar_recorridos/5`:

      Robot.buscar_recorridos(edificio, terrenos, b, Robot.Estadisticas.nuevo(),
                              &Robot.Estadisticas.actualizar/2)
  """
  def actualizar(%Recorrido{} = recorrido, %__MODULE__{} = estadisticas) do
    {min_mov, menos_mov} =
      mejorar(
        estadisticas.min_movimientos,
        estadisticas.menos_movimientos,
        Recorrido.movimientos(recorrido),
        recorrido
      )

    {min_en, menor_en} =
      mejorar(estadisticas.min_energia, estadisticas.menor_energia, recorrido.energia, recorrido)

    %{
      estadisticas
      | total: estadisticas.total + 1,
        min_movimientos: min_mov,
        menos_movimientos: menos_mov,
        min_energia: min_en,
        menor_energia: menor_en
    }
  end

  @doc """
  Primer recorrido encontrado con el menor número de movimientos (o `nil`).
  """
  def primero_menos_movimientos(%__MODULE__{menos_movimientos: [primero | _]}), do: primero
  def primero_menos_movimientos(%__MODULE__{}), do: nil

  @doc """
  Primer recorrido encontrado con la menor energía (o `nil`). Es el que se dibuja
  en `ruta_optima.svg`.
  """
  def primero_menor_energia(%__MODULE__{menor_energia: [primero | _]}), do: primero
  def primero_menor_energia(%__MODULE__{}), do: nil

  # -----------------------------------
  # Funciones auxiliares privadas
  # -----------------------------------

  # Actualiza un criterio (mínimo y lista de empates) con el valor de un recorrido.

  # Sin mínimo todavía: este es el primero.
  defp mejorar(nil, _empates, valor, recorrido), do: {valor, [recorrido]}

  # Mejor que el mínimo: la lista de empates se reemplaza.
  defp mejorar(minimo, _empates, valor, recorrido) when valor < minimo, do: {valor, [recorrido]}

  # Empate: se conserva en orden de aparición.
  defp mejorar(minimo, empates, valor, recorrido) when valor == minimo,
    do: {minimo, empates ++ [recorrido]}

  # Peor que el mínimo: no cambia nada.
  defp mejorar(minimo, empates, _valor, _recorrido), do: {minimo, empates}
end
