defmodule RobotTest do
  use ExUnit.Case, async: true

  alias Robot.Estadisticas

  # -----------------------------------
  # Datos de prueba
  # -----------------------------------

  defp terrenos(costo_lodo \\ 3) do
    Terreno.indexar([
      %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0},
      %Terreno{simbolo: ".", nombre: "pasillo", transitable: true, costo: 1},
      %Terreno{simbolo: "L", nombre: "lodo", transitable: true, costo: costo_lodo},
      %Terreno{simbolo: "S", nombre: "inicio", transitable: true, costo: 0},
      %Terreno{simbolo: "M", nombre: "meta", transitable: true, costo: 1}
    ])
  end

  # Ejemplo del enunciado
  defp edificio_enunciado do
    [
      ~w(X X X X X X),
      ~w(X S . L M X),
      ~w(X . X . . X),
      ~w(X . . . . X),
      ~w(X X X X X X)
    ]
  end

  defp estadisticas(edificio, terrenos, b) do
    Robot.buscar_recorridos(edificio, terrenos, b, Estadisticas.nuevo(), &Estadisticas.actualizar/2)
  end

  # -----------------------------------
  # buscar_recorridos/5
  # -----------------------------------

  test "ejemplo del enunciado con B = 10" do
    est = estadisticas(edificio_enunciado(), terrenos(), 10)

    assert est.total == 6
    assert est.min_movimientos == 3
    assert est.min_energia == 5

    # En este mapa ambos criterios coinciden en un único recorrido, el primero encontrado
    [{id, recorrido}] = est.menos_movimientos
    assert id == 1
    assert recorrido.posiciones == [{1, 1}, {1, 2}, {1, 3}, {1, 4}]
    assert recorrido.energia == 5
    assert est.menor_energia == est.menos_movimientos
  end

  test "entrega cada recorrido a la función receptora, en el orden fijo de direcciones" do
    # El acumulador es una lista de energías en orden de llegada (no una lista de recorridos)
    energias =
      Robot.buscar_recorridos(edificio_enunciado(), terrenos(), 10, [], fn recorrido, acc ->
        acc ++ [recorrido.energia]
      end)

    assert hd(energias) == 5
    assert length(energias) == 6
  end

  test "el límite B es inclusivo: energía igual a B sí se acepta" do
    assert estadisticas(edificio_enunciado(), terrenos(), 5).total == 1
  end

  test "B insuficiente: no hay recorridos" do
    est = estadisticas(edificio_enunciado(), terrenos(), 4)

    assert est.total == 0
    assert est.menos_movimientos == []
    assert est.menor_energia == []
    assert Estadisticas.primero_menor_energia(est) == nil
  end

  test "sin ruta: la meta está encerrada" do
    edificio = [
      ~w(X X X X X),
      ~w(X S X M X),
      ~w(X X X X X)
    ]

    assert estadisticas(edificio, terrenos(), 100).total == 0
  end

  test "empates: dos recorridos iguales en movimientos y energía" do
    edificio = [
      ~w(X X X X),
      ~w(X S . X),
      ~w(X . M X),
      ~w(X X X X)
    ]

    est = estadisticas(edificio, terrenos(), 10)

    assert est.total == 2
    assert length(est.menos_movimientos) == 2
    assert length(est.menor_energia) == 2

    # El primero encontrado va por la derecha (orden fijo arriba, derecha, abajo, izquierda)
    assert Estadisticas.primero_menor_energia(est).posiciones == [{1, 1}, {1, 2}, {2, 2}]
    assert Estadisticas.primero_menos_movimientos(est).posiciones == [{1, 1}, {1, 2}, {2, 2}]
  end

  test "los criterios de menos movimientos y menor energía pueden no coincidir" do
    edificio = [
      ~w(X X X X X),
      ~w(X S L M X),
      ~w(X . . . X),
      ~w(X X X X X)
    ]

    est = estadisticas(edificio, terrenos(5), 10)

    assert est.total == 4

    # Menos movimientos: atravesar el lodo (2 movimientos, energía 6)
    assert est.min_movimientos == 2
    assert [{_id, %Recorrido{energia: 6}}] = est.menos_movimientos

    # Menor energía: rodear por el pasillo (4 movimientos, energía 4)
    assert est.min_energia == 4
    assert [{_id, %Recorrido{posiciones: posiciones}}] = est.menor_energia
    assert posiciones == [{1, 1}, {2, 1}, {2, 2}, {2, 3}, {1, 3}]
  end

  test "los costos se leen de la tabla de terrenos, no del código" do
    # Si el lodo cuesta 1, el recorrido por el lodo baja de 5 a 3
    est = estadisticas(edificio_enunciado(), terrenos(1), 10)
    assert est.min_energia == 3
  end

  test "un símbolo sin definir en la tabla de terrenos se trata como no transitable" do
    edificio = [
      ~w(X X X X X),
      ~w(X S ? M X),
      ~w(X X X X X)
    ]

    assert estadisticas(edificio, terrenos(), 100).total == 0
  end

  test "edificio sin S no genera recorridos" do
    edificio = [~w(X X X), ~w(X M X), ~w(X X X)]
    assert estadisticas(edificio, terrenos(), 10).total == 0
  end

  test "Estadisticas.nuevo/0 arranca vacía" do
    est = Estadisticas.nuevo()

    assert est.total == 0
    assert est.min_movimientos == nil
    assert est.min_energia == nil
  end

  # -----------------------------------
  # stream_relajacion/3 y expansion/3
  # -----------------------------------

  test "stream_relajacion: el paso 0 es solo S con costo 0 y el paso 1 agrega vecinos" do
    [e0, e1] = Robot.stream_relajacion(edificio_enunciado(), terrenos(), 10) |> Enum.take(2)

    assert e0 == %{{1, 1} => 0}
    assert e1 == %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1}
  end

  test "stream_relajacion es infinito: se pueden tomar más pasos de los necesarios" do
    pasos = Robot.stream_relajacion(edificio_enunciado(), terrenos(), 10) |> Enum.take(50)

    assert length(pasos) == 50
    assert Enum.at(pasos, 49) == Enum.at(pasos, 6)
  end

  test "stream_relajacion descarta los costos mayores que B" do
    final = Robot.stream_relajacion(edificio_enunciado(), terrenos(), 3) |> Enum.at(30)

    assert Enum.all?(final, fn {_posicion, costo} -> costo <= 3 end)
    refute Map.has_key?(final, {1, 4})
  end

  test "expansion: pasos distintos e índice de estabilización" do
    {pasos, indice} = Robot.expansion(edificio_enunciado(), terrenos(), 10)

    assert indice == 6
    assert length(pasos) == 6
    assert Enum.uniq(pasos) == pasos

    final = List.last(pasos)
    assert final[{1, 4}] == 5
    assert final[{1, 3}] == 4
    assert final[{3, 4}] == 5
  end

  test "meta_alcanzable?: filtro para omitir la enumeración" do
    meta = Robot.ubicar(edificio_enunciado(), "M")
    assert meta == {1, 4}

    {pasos, _} = Robot.expansion(edificio_enunciado(), terrenos(), 10)
    assert Robot.meta_alcanzable?({List.last(pasos), meta})

    # B = 4 es menor que la energía mínima (5): la meta no es alcanzable
    {pasos_b4, _} = Robot.expansion(edificio_enunciado(), terrenos(), 4)
    refute Robot.meta_alcanzable?({List.last(pasos_b4), meta})
  end

  test "meta encerrada: la relajación se estabiliza sin alcanzar la meta" do
    edificio = [~w(X X X X X), ~w(X S X M X), ~w(X X X X X)]
    {pasos, indice} = Robot.expansion(edificio, terrenos(), 100)

    assert indice == 1
    assert pasos == [%{{1, 1} => 0}]
    refute Robot.meta_alcanzable?({List.last(pasos), {1, 3}})
  end
end
