defmodule SvgXmlTest do
  @moduledoc """
  Comprueba que todos los SVG generados sean XML bien formado (lo mismo que exige
  el navegador al abrirlos), usando el parser :xmerl que viene con Erlang/OTP.
  """
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  @fixtures Path.expand("fixtures", __DIR__)

  defp bien_formado?(ruta) do
    bytes = ruta |> File.read!() |> :erlang.binary_to_list()

    try do
      {_documento, _resto} = :xmerl_scan.string(bytes, quiet: true)
      true
    catch
      :exit, _motivo -> false
    end
  end

  defp cargar do
    {:ok, filas, []} = Lector.leer_edificio(Path.join(@fixtures, "edificio.txt"))
    {:ok, terrenos, []} = Lector.leer_terrenos(Path.join(@fixtures, "terrenos.csv"))
    {Lector.construir_mapa(filas), Lector.indice_terrenos(terrenos)}
  end

  test "ruta_optima.svg con y sin recorrido es XML válido", %{tmp_dir: tmp} do
    {mapa, indice} = cargar()
    con = Path.join(tmp, "con.svg")
    sin = Path.join(tmp, "sin.svg")

    recorrido = %Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}, {1, 4}], energia: 5}
    :ok = Svg.escribir_ruta(con, mapa, indice, recorrido)
    :ok = Svg.escribir_ruta(sin, mapa, indice, nil)

    assert bien_formado?(con)
    assert bien_formado?(sin)
  end

  test "ruta_optima.svg con texto que requiere escape es XML válido", %{tmp_dir: tmp} do
    {mapa, indice} = cargar()

    indice =
      Map.put(indice, "L", %Terreno{
        simbolo: "L",
        nombre: "lodo <&> \"feo\" 'raro'",
        transitable: true,
        costo: 3
      })

    ruta = Path.join(tmp, "escape.svg")
    :ok = Svg.escribir_ruta(ruta, mapa, indice, nil)
    assert bien_formado?(ruta)
  end

  test "mejor_plan.svg con plan, sin plan y con IDs especiales es XML válido", %{tmp_dir: tmp} do
    plan = %Plan{
      orden: ["A", "B&C"],
      finalizaciones: [{"A", 0, 3}, {"B&C", 3, 5}],
      penalizacion: 1
    }

    tareas = [
      %Tarea{id: "A", duracion: 3, plazo: 4, dependencias: []},
      %Tarea{id: "B&C", duracion: 2, plazo: 4, dependencias: ["A"]}
    ]

    con = Path.join(tmp, "plan.svg")
    sin = Path.join(tmp, "sin_plan.svg")
    :ok = Svg.escribir_gantt(con, plan, tareas)
    :ok = Svg.escribir_gantt(sin, nil, [])

    assert bien_formado?(con)
    assert bien_formado?(sin)
  end
end
