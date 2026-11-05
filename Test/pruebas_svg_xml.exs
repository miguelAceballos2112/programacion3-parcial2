# Comprueba que los SVG sean XML bien formado, lo mismo que exige el navegador al
# abrirlos. Usa el analizador :xmerl que viene con Erlang.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_svg_xml.exs

defmodule PruebasSvgXml do
  def main do
    Pruebas.ejecutar(casos_ruta() ++ caso_ruta_escape() ++ casos_gantt() ++ casos_generados())
  end

  # :xmerl termina el proceso con exit cuando el XML está mal formado
  defp bien_formado?(ruta) do
    contenido = ruta |> File.read!() |> :erlang.binary_to_list()

    try do
      {_documento, _resto} = :xmerl_scan.string(contenido, quiet: true)
      true
    catch
      :exit, _motivo -> false
    end
  end

  defp cargar do
    {:ok, filas, []} = Lector.leer_edificio("fixtures/lector/edificio.txt")
    {:ok, terrenos, []} = Lector.leer_terrenos("fixtures/lector/terrenos.csv")
    {Lector.construir_mapa(filas), Lector.indice_terrenos(terrenos)}
  end

  defp casos_ruta do
    {mapa, indice} = cargar()
    con = Pruebas.temporal("xml_con.svg")
    sin = Pruebas.temporal("xml_sin.svg")
    recorrido = %Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}, {1, 4}], energia: 5}

    Svg.escribir_ruta(con, mapa, indice, recorrido)
    Svg.escribir_ruta(sin, mapa, indice, nil)

    [
      {"ruta con recorrido", bien_formado?(con), true},
      {"ruta sin recorrido", bien_formado?(sin), true}
    ]
  end

  defp caso_ruta_escape do
    {mapa, indice} = cargar()
    indice = Map.put(indice, "L", Terreno.crear("L", "lodo <&> \"feo\" 'raro'", true, 3))
    ruta = Pruebas.temporal("xml_escape.svg")
    Svg.escribir_ruta(ruta, mapa, indice, nil)

    [{"ruta con texto que requiere escape", bien_formado?(ruta), true}]
  end

  defp casos_gantt do
    plan = %Plan{
      orden: ["A", "B&C"],
      finalizaciones: [{"A", 0, 3}, {"B&C", 3, 5}],
      penalizacion: 1
    }

    tareas = [Tarea.crear("A", 3, 4, []), Tarea.crear("B&C", 2, 4, ["A"])]
    con = Pruebas.temporal("xml_plan.svg")
    sin = Pruebas.temporal("xml_sin_plan.svg")

    Svg.escribir_gantt(con, plan, tareas)
    Svg.escribir_gantt(sin, nil, [])

    [
      {"gantt con IDs especiales", bien_formado?(con), true},
      {"gantt sin plan", bien_formado?(sin), true}
    ]
  end

  # Los SVG que deja el programa en los casos de prueba de punta a punta
  defp casos_generados do
    Orquestador.rescate("fixtures/rescate/valido")
    Orquestador.rescate("fixtures/rescate/limite_sin_recorrido")
    Orquestador.tareas("fixtures/tareas/valido")
    Orquestador.tareas("fixtures/tareas/vacio")

    [
      {"programa: ruta con recorrido", bien_formado?("fixtures/rescate/valido/ruta_optima.svg"), true},
      {"programa: ruta sin recorrido", bien_formado?("fixtures/rescate/limite_sin_recorrido/ruta_optima.svg"), true},
      {"programa: gantt", bien_formado?("fixtures/tareas/valido/mejor_plan.svg"), true},
      {"programa: gantt sin plan", bien_formado?("fixtures/tareas/vacio/mejor_plan.svg"), true}
    ]
  end
end

PruebasSvgXml.main()
