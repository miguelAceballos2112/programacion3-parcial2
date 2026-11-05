# Pruebas de Robot y Robot.Estadisticas.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_robot.exs

defmodule PruebasRobot do
  def main do
    Pruebas.ejecutar(casos_recorridos() ++ casos_relajacion())
  end

  # -----------------------------------
  # Datos de prueba
  # -----------------------------------

  defp terrenos(), do: terrenos(3)

  defp terrenos(costo_lodo) do
    Terreno.indexar([
      Terreno.crear("X", "pared", false, 0),
      Terreno.crear(".", "pasillo", true, 1),
      Terreno.crear("L", "lodo", true, costo_lodo),
      Terreno.crear("S", "inicio", true, 0),
      Terreno.crear("M", "meta", true, 1)
    ])
  end

  # Ejemplo del enunciado
  defp edificio_enunciado do
    [
      ["X", "X", "X", "X", "X", "X"],
      ["X", "S", ".", "L", "M", "X"],
      ["X", ".", "X", ".", ".", "X"],
      ["X", ".", ".", ".", ".", "X"],
      ["X", "X", "X", "X", "X", "X"]
    ]
  end

  defp meta_encerrada do
    [
      ["X", "X", "X", "X", "X"],
      ["X", "S", "X", "M", "X"],
      ["X", "X", "X", "X", "X"]
    ]
  end

  defp estadisticas(edificio, tabla, b) do
    Robot.buscar_recorridos(edificio, tabla, b, Robot.Estadisticas.nuevo(), &Robot.Estadisticas.actualizar/2)
  end

  # -----------------------------------
  # buscar_recorridos/5
  # -----------------------------------

  defp casos_recorridos do
    caso_enunciado() ++
      caso_receptora() ++
      caso_limite_b() ++
      caso_sin_ruta() ++
      caso_empates() ++
      caso_criterios_distintos() ++
      caso_otros_terrenos() ++
      caso_estadisticas_vacias()
  end

  defp caso_enunciado do
    est = estadisticas(edificio_enunciado(), terrenos(), 10)
    [{id, recorrido}] = est.menos_movimientos

    [
      {"enunciado: total", est.total, 6},
      {"enunciado: mínimo de movimientos", est.min_movimientos, 3},
      {"enunciado: mínimo de energía", est.min_energia, 5},
      {"enunciado: id del mejor recorrido", id, 1},
      {"enunciado: posiciones", recorrido.posiciones, [{1, 1}, {1, 2}, {1, 3}, {1, 4}]},
      {"enunciado: energía", recorrido.energia, 5},
      {"enunciado: ambos criterios coinciden", est.menor_energia, est.menos_movimientos}
    ]
  end

  # El acumulador es una lista de energías en orden de llegada
  defp caso_receptora do
    energias =
      Robot.buscar_recorridos(edificio_enunciado(), terrenos(), 10, [], fn recorrido, acumulado ->
        acumulado ++ [recorrido.energia]
      end)

    [
      {"receptora: orden fijo de direcciones", Enum.at(energias, 0), 5},
      {"receptora: recibe todos los recorridos", length(energias), 6}
    ]
  end

  defp caso_limite_b do
    est = estadisticas(edificio_enunciado(), terrenos(), 4)

    [
      {"B inclusivo: energía igual a B se acepta",
       estadisticas(edificio_enunciado(), terrenos(), 5).total, 1},
      {"B insuficiente: total", est.total, 0},
      {"B insuficiente: sin menos movimientos", est.menos_movimientos, []},
      {"B insuficiente: sin menor energía", est.menor_energia, []},
      {"B insuficiente: sin primero", Robot.Estadisticas.primero_menor_energia(est), nil}
    ]
  end

  defp caso_sin_ruta do
    [{"sin ruta: meta encerrada", estadisticas(meta_encerrada(), terrenos(), 100).total, 0}]
  end

  defp caso_empates do
    edificio = [
      ["X", "X", "X", "X"],
      ["X", "S", ".", "X"],
      ["X", ".", "M", "X"],
      ["X", "X", "X", "X"]
    ]

    est = estadisticas(edificio, terrenos(), 10)
    primero = [{1, 1}, {1, 2}, {2, 2}]

    [
      {"empates: total", est.total, 2},
      {"empates: en movimientos", length(est.menos_movimientos), 2},
      {"empates: en energía", length(est.menor_energia), 2},
      {"empates: primero de menor energía va por la derecha",
       Robot.Estadisticas.primero_menor_energia(est).posiciones, primero},
      {"empates: primero de menos movimientos va por la derecha",
       Robot.Estadisticas.primero_menos_movimientos(est).posiciones, primero}
    ]
  end

  defp caso_criterios_distintos do
    edificio = [
      ["X", "X", "X", "X", "X"],
      ["X", "S", "L", "M", "X"],
      ["X", ".", ".", ".", "X"],
      ["X", "X", "X", "X", "X"]
    ]

    est = estadisticas(edificio, terrenos(5), 10)
    [{_id_corto, corto}] = est.menos_movimientos
    [{_id_barato, barato}] = est.menor_energia

    [
      {"criterios distintos: total", est.total, 4},
      {"criterios distintos: menos movimientos", est.min_movimientos, 2},
      {"criterios distintos: energía de atravesar el lodo", corto.energia, 6},
      {"criterios distintos: menor energía", est.min_energia, 4},
      {"criterios distintos: rodea por el pasillo", barato.posiciones,
       [{1, 1}, {2, 1}, {2, 2}, {2, 3}, {1, 3}]}
    ]
  end

  defp caso_otros_terrenos do
    con_simbolo_raro = [
      ["X", "X", "X", "X", "X"],
      ["X", "S", "?", "M", "X"],
      ["X", "X", "X", "X", "X"]
    ]

    sin_inicio = [
      ["X", "X", "X"],
      ["X", "M", "X"],
      ["X", "X", "X"]
    ]

    [
      {"el costo viene de la tabla de terrenos",
       estadisticas(edificio_enunciado(), terrenos(1), 10).min_energia, 3},
      {"símbolo sin definir no es transitable",
       estadisticas(con_simbolo_raro, terrenos(), 100).total, 0},
      {"edificio sin S no genera recorridos", estadisticas(sin_inicio, terrenos(), 10).total, 0}
    ]
  end

  defp caso_estadisticas_vacias do
    est = Robot.Estadisticas.nuevo()

    [
      {"estadísticas nuevas: total", est.total, 0},
      {"estadísticas nuevas: movimientos", est.min_movimientos, nil},
      {"estadísticas nuevas: energía", est.min_energia, nil}
    ]
  end

  # -----------------------------------
  # stream_relajacion/3 y expansion/3
  # -----------------------------------

  defp casos_relajacion do
    caso_primeros_pasos() ++
      caso_stream_infinito() ++
      caso_descarta_mayores_que_b() ++
      caso_expansion() ++
      caso_meta_alcanzable() ++
      caso_expansion_meta_encerrada()
  end

  defp caso_primeros_pasos do
    [paso0, paso1] = Robot.stream_relajacion(edificio_enunciado(), terrenos(), 10) |> Enum.take(2)

    [
      {"relajación: paso 0 solo S", paso0, %{{1, 1} => 0}},
      {"relajación: paso 1 agrega vecinos", paso1, %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1}}
    ]
  end

  defp caso_stream_infinito do
    pasos = Robot.stream_relajacion(edificio_enunciado(), terrenos(), 10) |> Enum.take(50)

    [
      {"relajación: se pueden tomar 50 pasos", length(pasos), 50},
      {"relajación: sigue estable", Enum.at(pasos, 49), Enum.at(pasos, 6)}
    ]
  end

  defp caso_descarta_mayores_que_b do
    final = Robot.stream_relajacion(edificio_enunciado(), terrenos(), 3) |> Enum.at(30)

    [
      {"relajación: ningún costo supera B",
       Enum.filter(final, fn {_posicion, costo} -> costo > 3 end), []},
      {"relajación: la meta queda fuera",
       Enum.filter(final, fn {posicion, _costo} -> posicion == {1, 4} end), []}
    ]
  end

  defp caso_expansion do
    {pasos, indice} = Robot.expansion(edificio_enunciado(), terrenos(), 10)
    %{{1, 4} => costo_meta, {1, 3} => costo_lodo, {3, 4} => costo_abajo} = Enum.at(pasos, -1)

    [
      {"expansión: índice de estabilización", indice, 6},
      {"expansión: cantidad de pasos", length(pasos), 6},
      {"expansión: pasos distintos", Enum.uniq(pasos), pasos},
      {"expansión: costo de la meta", costo_meta, 5},
      {"expansión: costo del lodo", costo_lodo, 4},
      {"expansión: costo de (3,4)", costo_abajo, 5}
    ]
  end

  defp caso_meta_alcanzable do
    meta = Robot.ubicar(edificio_enunciado(), "M")
    {pasos, _indice} = Robot.expansion(edificio_enunciado(), terrenos(), 10)
    {pasos_b4, _indice} = Robot.expansion(edificio_enunciado(), terrenos(), 4)

    [
      {"filtro: ubica la meta", meta, {1, 4}},
      {"filtro: B = 10 alcanza", Robot.meta_alcanzable?({Enum.at(pasos, -1), meta}), true},
      {"filtro: B = 4 no alcanza", Robot.meta_alcanzable?({Enum.at(pasos_b4, -1), meta}), false}
    ]
  end

  defp caso_expansion_meta_encerrada do
    {pasos, indice} = Robot.expansion(meta_encerrada(), terrenos(), 100)

    [
      {"meta encerrada: índice", indice, 1},
      {"meta encerrada: pasos", pasos, [%{{1, 1} => 0}]},
      {"meta encerrada: no alcanzable",
       Robot.meta_alcanzable?({Enum.at(pasos, -1), {1, 3}}), false}
    ]
  end
end

PruebasRobot.main()
