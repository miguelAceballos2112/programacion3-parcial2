# Ejecutar con:  elixir test/planificador_test.exs
Code.require_file("../planificador/planificador.exs", __DIR__)

ExUnit.start()

defmodule PlanificadorTest do
  use ExUnit.Case

  alias Planificador.Estadisticas

  # -----------------------------------
  # Datos de prueba y ayudas
  # -----------------------------------

  # Ejemplo del enunciado
  defp tareas_enunciado do
    [
      %Tarea{id: "A", duracion: 3, plazo: 4, dependencias: []},
      %Tarea{id: "B", duracion: 2, plazo: 5, dependencias: ["A"]},
      %Tarea{id: "C", duracion: 4, plazo: 6, dependencias: ["A"]},
      %Tarea{id: "D", duracion: 1, plazo: 9, dependencias: ["B", "C"]}
    ]
  end

  # Acumula los planes en una lista (solo para poder inspeccionarlos en las pruebas)
  defp todos_los_planes(tareas) do
    Planificador.generar_planes(tareas, [], fn plan, acc -> acc ++ [plan] end)
  end

  defp estadisticas(tareas) do
    Planificador.generar_planes(tareas, Estadisticas.nuevo(), &Estadisticas.actualizar/2)
  end

  # -----------------------------------
  # generar_planes/3
  # -----------------------------------

  test "ejemplo del enunciado: dos planes, en orden alfabético por ID" do
    [plan1, plan2] = todos_los_planes(tareas_enunciado())

    assert plan1.orden == ["A", "B", "C", "D"]
    assert plan1.penalizacion == 4
    assert plan1.finalizaciones == [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}]
    assert Plan.duracion_total(plan1) == 10

    assert plan2.orden == ["A", "C", "B", "D"]
    assert plan2.penalizacion == 6
    assert plan2.finalizaciones == [{"A", 0, 3}, {"C", 3, 7}, {"B", 7, 9}, {"D", 9, 10}]
    assert Plan.duracion_total(plan2) == 10
  end

  test "estadísticas del ejemplo: total, penalización mínima y primer óptimo" do
    est = estadisticas(tareas_enunciado())

    assert est.total == 2
    assert est.penalizacion_minima == 4
    assert length(est.optimos) == 1
    assert Estadisticas.primer_optimo(est).orden == ["A", "B", "C", "D"]
  end

  test "proyecto vacío: no enumera ni llama a la función receptora" do
    resultado =
      Planificador.generar_planes([], :acc_inicial, fn _plan, _acc ->
        flunk("no debe generarse ningún plan")
      end)

    assert resultado == :acc_inicial

    est = estadisticas([])
    assert est.total == 0
    assert est.penalizacion_minima == nil
    assert Estadisticas.primer_optimo(est) == nil
  end

  test "una sola tarea: un único plan" do
    tareas = [%Tarea{id: "A", duracion: 5, plazo: 3, dependencias: []}]

    [plan] = todos_los_planes(tareas)

    assert plan.orden == ["A"]
    assert plan.finalizaciones == [{"A", 0, 5}]
    # fin 5 - plazo 3 = 2
    assert plan.penalizacion == 2
    assert Plan.duracion_total(plan) == 5

    est = estadisticas(tareas)
    assert est.total == 1
    assert est.penalizacion_minima == 2
  end

  test "empates: tareas independientes con la misma penalización" do
    tareas = [
      %Tarea{id: "B", duracion: 2, plazo: 10, dependencias: []},
      %Tarea{id: "A", duracion: 2, plazo: 10, dependencias: []}
    ]

    est = estadisticas(tareas)

    assert est.total == 2
    assert est.penalizacion_minima == 0
    assert length(est.optimos) == 2
    # El primero encontrado respeta el orden alfabético (aunque la entrada venga desordenada)
    assert Estadisticas.primer_optimo(est).orden == ["A", "B"]
  end

  test "sin dependencias: se generan todas las permutaciones (3! = 6)" do
    tareas = for id <- ["A", "B", "C"], do: %Tarea{id: id, duracion: 1, plazo: 3, dependencias: []}

    planes = todos_los_planes(tareas)

    assert length(planes) == 6
    assert hd(planes).orden == ["A", "B", "C"]
    assert List.last(planes).orden == ["C", "B", "A"]
  end

  test "ningún plan viola una dependencia" do
    planes = todos_los_planes(tareas_enunciado())

    assert Enum.all?(planes, fn plan ->
             hd(plan.orden) == "A" and List.last(plan.orden) == "D"
           end)
  end

  test "la penalización mínima puede estar en un plan que no es el primero" do
    tareas = [
      %Tarea{id: "A", duracion: 5, plazo: 10, dependencias: []},
      %Tarea{id: "B", duracion: 1, plazo: 1, dependencias: []}
    ]

    est = estadisticas(tareas)

    # A,B -> B termina en 6 (penaliza 5); B,A -> B en 1 (0) y A en 6 (0)
    assert est.total == 2
    assert est.penalizacion_minima == 0
    assert Estadisticas.primer_optimo(est).orden == ["B", "A"]
  end

  test "el acumulador lo controla quien llama (conteo sin guardar planes)" do
    cantidad = Planificador.generar_planes(tareas_enunciado(), 0, fn _plan, acc -> acc + 1 end)
    assert cantidad == 2
  end
end
