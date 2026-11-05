# Demostración del Rol 1 con los datos del enunciado.
# Ejecutar con:  elixir scripts/demo_rol1.exs
# Requiere util/Util2.ex y util/benchmark.ex (provistos por el docente).

Code.require_file("../util/Util2.ex", __DIR__)
Code.require_file("../util/benchmark.ex", __DIR__)
Code.require_file("../robot/robot.exs", __DIR__)
Code.require_file("../planificador/planificador.exs", __DIR__)

defmodule DemoRol1 do
  def main do
    robot()
    comparar_relajacion_y_enumeracion()
    planificador()
  end

  # -----------------------------------
  # Problema 1
  # -----------------------------------

  defp robot do
    Util2.mostrar("=== Problema 1: Robot ===", :mensaje)

    edificio = edificio_enunciado()
    terrenos = terrenos_enunciado()
    b = 10

    {pasos, indice} = Robot.expansion(edificio, terrenos, b)
    Util2.mostrar("Pasos distintos: #{length(pasos)}, índice de estabilización: #{indice}", :mensaje)

    meta = Robot.ubicar(edificio, "M")

    if Robot.meta_alcanzable?({List.last(pasos), meta}) do
      est = enumerar(edificio, terrenos, b)

      Util2.mostrar("Recorridos: #{est.total}", :mensaje)
      Util2.mostrar("Menos movimientos (#{est.min_movimientos}): #{length(est.menos_movimientos)}", :mensaje)
      Util2.mostrar("Menor energía (#{est.min_energia}): #{length(est.menor_energia)}", :mensaje)
    else
      Util2.mostrar("La meta no es alcanzable: se omite la enumeración.", :mensaje)
    end
  end

  # Compara el costo de la relajación (filtro) contra el de la enumeración completa
  # en una sala abierta de 5x5, donde hay miles de recorridos simples.
  defp comparar_relajacion_y_enumeracion do
    Util2.mostrar("\n=== Relajación vs enumeración (sala abierta 5x5) ===", :mensaje)

    interior = for _ <- 1..5, do: for(_ <- 1..5, do: ".")

    sala =
      [List.duplicate("X", 7)] ++
        Enum.map(interior, fn fila -> ["X"] ++ fila ++ ["X"] end) ++
        [List.duplicate("X", 7)]

    sala = sala |> List.update_at(1, &List.replace_at(&1, 1, "S")) |> List.update_at(5, &List.replace_at(&1, 5, "M"))
    terrenos = terrenos_enunciado()
    b = 100

    t_relajacion = Benchmark.determinar_tiempo_ejecucion({Robot, :expansion, [sala, terrenos, b]})

    t_enumeracion =
      Benchmark.determinar_tiempo_ejecucion(
        {Robot, :buscar_recorridos,
         [sala, terrenos, b, Robot.Estadisticas.nuevo(), &Robot.Estadisticas.actualizar/2]}
      )

    Util2.mostrar(Benchmark.generar_mensaje(t_relajacion, t_enumeracion), :mensaje)
    Util2.mostrar("Recorridos simples en la sala: #{enumerar(sala, terrenos, b).total}", :mensaje)
  end

  # -----------------------------------
  # Problema 2
  # -----------------------------------

  defp planificador do
    Util2.mostrar("\n=== Problema 2: Planificador ===", :mensaje)

    tareas = [
      %Tarea{id: "A", duracion: 3, plazo: 4, dependencias: []},
      %Tarea{id: "B", duracion: 2, plazo: 5, dependencias: ["A"]},
      %Tarea{id: "C", duracion: 4, plazo: 6, dependencias: ["A"]},
      %Tarea{id: "D", duracion: 1, plazo: 9, dependencias: ["B", "C"]}
    ]

    est =
      Planificador.generar_planes(
        tareas,
        Planificador.Estadisticas.nuevo(),
        &Planificador.Estadisticas.actualizar/2
      )

    Util2.mostrar("Planes: #{est.total}, penalización mínima: #{est.penalizacion_minima}", :mensaje)

    est.optimos
    |> Util2.convertir_coleccion_mensaje(fn plan ->
      " - #{Enum.join(plan.orden, " -> ")} (duración #{Plan.duracion_total(plan)})\n"
    end)
    |> Enum.each(&IO.write/1)
  end

  # -----------------------------------
  # Datos
  # -----------------------------------

  defp enumerar(edificio, terrenos, b) do
    Robot.buscar_recorridos(
      edificio,
      terrenos,
      b,
      Robot.Estadisticas.nuevo(),
      &Robot.Estadisticas.actualizar/2
    )
  end

  defp edificio_enunciado do
    [
      ~w(X X X X X X),
      ~w(X S . L M X),
      ~w(X . X . . X),
      ~w(X . . . . X),
      ~w(X X X X X X)
    ]
  end

  defp terrenos_enunciado do
    Terreno.indexar([
      %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0},
      %Terreno{simbolo: ".", nombre: "pasillo", transitable: true, costo: 1},
      %Terreno{simbolo: "L", nombre: "lodo", transitable: true, costo: 3},
      %Terreno{simbolo: "S", nombre: "inicio", transitable: true, costo: 0},
      %Terreno{simbolo: "M", nombre: "meta", transitable: true, costo: 1}
    ])
  end
end

DemoRol1.main()
