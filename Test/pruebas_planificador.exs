# Pruebas de Planificador y Planificador.Estadisticas.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_planificador.exs

defmodule PruebasPlanificador do
  def main do
    casos =
      caso_enunciado() ++
        caso_estadisticas_enunciado() ++
        caso_proyecto_vacio() ++
        caso_una_tarea() ++
        caso_empates() ++
        caso_permutaciones() ++
        caso_dependencias() ++
        caso_minimo_no_es_el_primero() ++
        caso_acumulador()

    Pruebas.ejecutar(casos)
  end

  # -----------------------------------
  # Datos de prueba
  # -----------------------------------

  # Ejemplo del enunciado
  defp tareas_enunciado do
    [
      Tarea.crear("A", 3, 4, []),
      Tarea.crear("B", 2, 5, ["A"]),
      Tarea.crear("C", 4, 6, ["A"]),
      Tarea.crear("D", 1, 9, ["B", "C"])
    ]
  end

  # Acumula los planes en una lista, solo para revisarlos en las pruebas
  defp todos_los_planes(tareas) do
    Planificador.generar_planes(tareas, [], fn plan, acumulado -> acumulado ++ [plan] end)
  end

  defp estadisticas(tareas) do
    Planificador.generar_planes(tareas, Planificador.Estadisticas.nuevo(), &Planificador.Estadisticas.actualizar/2)
  end

  # -----------------------------------
  # generar_planes/3
  # -----------------------------------

  defp caso_enunciado do
    [plan1, plan2] = todos_los_planes(tareas_enunciado())

    [
      {"enunciado: orden del plan 1", plan1.orden, ["A", "B", "C", "D"]},
      {"enunciado: penalización del plan 1", plan1.penalizacion, 4},
      {"enunciado: finalizaciones del plan 1", plan1.finalizaciones,
       [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}]},
      {"enunciado: duración del plan 1", Plan.duracion_total(plan1), 10},
      {"enunciado: orden del plan 2", plan2.orden, ["A", "C", "B", "D"]},
      {"enunciado: penalización del plan 2", plan2.penalizacion, 6},
      {"enunciado: finalizaciones del plan 2", plan2.finalizaciones,
       [{"A", 0, 3}, {"C", 3, 7}, {"B", 7, 9}, {"D", 9, 10}]},
      {"enunciado: duración del plan 2", Plan.duracion_total(plan2), 10}
    ]
  end

  defp caso_estadisticas_enunciado do
    est = estadisticas(tareas_enunciado())
    [{id, _plan}] = est.optimos

    [
      {"estadísticas: total", est.total, 2},
      {"estadísticas: penalización mínima", est.penalizacion_minima, 4},
      {"estadísticas: id del óptimo", id, 1},
      {"estadísticas: primer óptimo", Planificador.Estadisticas.primer_optimo(est).orden,
       ["A", "B", "C", "D"]}
    ]
  end

  defp caso_proyecto_vacio do
    resultado = Planificador.generar_planes([], :inicial, fn _plan, _acumulado -> :se_llamo end)
    est = estadisticas([])

    [
      {"vacío: no llama a la receptora", resultado, :inicial},
      {"vacío: total", est.total, 0},
      {"vacío: penalización", est.penalizacion_minima, nil},
      {"vacío: sin óptimo", Planificador.Estadisticas.primer_optimo(est), nil}
    ]
  end

  defp caso_una_tarea do
    tareas = [Tarea.crear("A", 5, 3, [])]
    [plan] = todos_los_planes(tareas)
    est = estadisticas(tareas)

    [
      {"una tarea: orden", plan.orden, ["A"]},
      {"una tarea: finalizaciones", plan.finalizaciones, [{"A", 0, 5}]},
      {"una tarea: penalización de 5 - 3", plan.penalizacion, 2},
      {"una tarea: duración", Plan.duracion_total(plan), 5},
      {"una tarea: total", est.total, 1},
      {"una tarea: penalización mínima", est.penalizacion_minima, 2}
    ]
  end

  # La entrada viene desordenada: el primer óptimo respeta el orden alfabético
  defp caso_empates do
    est = estadisticas([Tarea.crear("B", 2, 10, []), Tarea.crear("A", 2, 10, [])])

    [
      {"empates: total", est.total, 2},
      {"empates: penalización mínima", est.penalizacion_minima, 0},
      {"empates: cantidad de óptimos", length(est.optimos), 2},
      {"empates: primero alfabético", Planificador.Estadisticas.primer_optimo(est).orden, ["A", "B"]}
    ]
  end

  defp caso_permutaciones do
    tareas = [Tarea.crear("A", 1, 3, []), Tarea.crear("B", 1, 3, []), Tarea.crear("C", 1, 3, [])]
    planes = todos_los_planes(tareas)

    [
      {"sin dependencias: 3! planes", length(planes), 6},
      {"sin dependencias: primero", Enum.at(planes, 0).orden, ["A", "B", "C"]},
      {"sin dependencias: último", Enum.at(planes, -1).orden, ["C", "B", "A"]}
    ]
  end

  defp caso_dependencias do
    planes = todos_los_planes(tareas_enunciado())

    [
      {"dependencias: todos empiezan por A y terminan en D",
       Enum.map(planes, fn plan -> {Enum.at(plan.orden, 0), Enum.at(plan.orden, -1)} end),
       [{"A", "D"}, {"A", "D"}]}
    ]
  end

  # A,B: B termina en 6 y penaliza 5. B,A: B termina en 1 y A en 6, sin penalizar.
  defp caso_minimo_no_es_el_primero do
    est = estadisticas([Tarea.crear("A", 5, 10, []), Tarea.crear("B", 1, 1, [])])
    [{id, _plan}] = est.optimos

    [
      {"mínimo posterior: total", est.total, 2},
      {"mínimo posterior: penalización", est.penalizacion_minima, 0},
      {"mínimo posterior: id del segundo plan", id, 2},
      {"mínimo posterior: orden", Planificador.Estadisticas.primer_optimo(est).orden, ["B", "A"]}
    ]
  end

  defp caso_acumulador do
    cantidad = Planificador.generar_planes(tareas_enunciado(), 0, fn _plan, cuenta -> cuenta + 1 end)

    [{"acumulador: cuenta sin guardar planes", cantidad, 2}]
  end
end

PruebasPlanificador.main()
