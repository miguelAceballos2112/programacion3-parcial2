# Pruebas de Svg.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_svg.exs

defmodule PruebasSvg do
  def main do
    casos =
      casos_escapar() ++
        casos_ruta_con_recorrido() ++
        casos_ruta_sin_recorrido() ++
        caso_escape_terrenos() ++
        casos_colores() ++
        caso_una_casilla() ++
        casos_gantt() ++
        caso_gantt_sin_plan() ++
        caso_gantt_escape() ++
        caso_gantt_una_tarea()

    Pruebas.ejecutar(casos)
  end

  # -----------------------------------
  # Datos de apoyo
  # -----------------------------------

  defp cargar do
    {:ok, filas, []} = Lector.leer_edificio("fixtures/lector/edificio.txt")
    {:ok, terrenos, []} = Lector.leer_terrenos("fixtures/lector/terrenos.csv")
    {Lector.construir_mapa(filas), Lector.indice_terrenos(terrenos)}
  end

  defp tareas_ejemplo do
    [
      Tarea.crear("A", 3, 4, []),
      Tarea.crear("B", 2, 5, ["A"]),
      Tarea.crear("C", 4, 6, ["A"]),
      Tarea.crear("D", 1, 9, ["B", "C"])
    ]
  end

  defp plan_ejemplo do
    %Plan{
      orden: ["A", "B", "C", "D"],
      finalizaciones: [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}],
      penalizacion: 4
    }
  end

  defp contiene(nombre, texto, parte), do: {nombre, Pruebas.contiene_texto?(texto, parte), true}
  defp no_contiene(nombre, texto, parte), do: {nombre, Pruebas.contiene_texto?(texto, parte), false}
  defp cierra(nombre, svg), do: {nombre, String.ends_with?(svg, "</svg>\n"), true}
  defp abre(nombre, svg), do: {nombre, String.starts_with?(svg, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"), true}

  # -----------------------------------
  # escapar
  # -----------------------------------

  defp casos_escapar do
    [
      {"escapa caracteres XML", Svg.escapar("a<b & \"c\" 'd' >"), "a&lt;b &amp; &quot;c&quot; &apos;d&apos; &gt;"},
      {"texto normal", Svg.escapar("normal"), "normal"},
      {"número", Svg.escapar(42), "42"}
    ]
  end

  # -----------------------------------
  # ruta_optima.svg
  # -----------------------------------

  defp casos_ruta_con_recorrido do
    {mapa, indice} = cargar()
    ruta = Pruebas.temporal("ruta_optima.svg")

    recorrido = %Recorrido{
      posiciones: [{1, 1}, {1, 2}, {2, 2}, {3, 2}, {3, 3}, {3, 4}, {2, 4}, {1, 4}],
      energia: 6
    }

    Svg.escribir_ruta(ruta, mapa, indice, recorrido)
    svg = File.read!(ruta)

    [
      abre("ruta: encabezado XML", svg),
      cierra("ruta: cierre", svg),
      contiene("ruta: ancho", svg, "width=\"280\" height="),
      contiene("ruta: línea del recorrido", svg, "<polyline"),
      contiene("ruta: centros de las casillas", svg, "points=\"60,60 100,60 100,100 100,140 140,140 180,140 180,100 180,60\""),
      no_contiene("ruta: sin la leyenda de no recorrido", svg, "sin recorrido"),
      contiene("ruta: leyenda", svg, "Ruta de menor energía: 6 de energía, 7 movimientos"),
      {"ruta: 30 casillas de 40x40", Pruebas.ocurrencias(svg, "width=\"40\" height=\"40\""), 30}
    ]
  end

  defp casos_ruta_sin_recorrido do
    {mapa, indice} = cargar()
    ruta = Pruebas.temporal("ruta_sin_recorrido.svg")
    Svg.escribir_ruta(ruta, mapa, indice, nil)
    svg = File.read!(ruta)

    [
      contiene("sin ruta: leyenda", svg, "sin recorrido"),
      no_contiene("sin ruta: sin línea", svg, "<polyline"),
      {"sin ruta: dibuja el mapa", Pruebas.ocurrencias(svg, "width=\"40\" height=\"40\""), 30},
      cierra("sin ruta: cierre", svg)
    ]
  end

  defp caso_escape_terrenos do
    {mapa, indice} = cargar()
    indice = Map.put(indice, "L", Terreno.crear("L", "lodo <&> \"feo\"", true, 3))
    ruta = Pruebas.temporal("ruta_escape.svg")
    Svg.escribir_ruta(ruta, mapa, indice, nil)
    svg = File.read!(ruta)

    [
      contiene("escape: nombre escapado", svg, "lodo &lt;&amp;&gt; &quot;feo&quot;"),
      no_contiene("escape: sin texto crudo", svg, "lodo <&>")
    ]
  end

  defp casos_colores do
    {_mapa, indice} = cargar()
    colores = Svg.colores_terrenos(indice)
    %{"X" => pared, "." => pasillo, "L" => lodo} = colores

    [
      {"colores: pared", pared, "#37474f"},
      {"colores: pasillo y lodo son distintos", pasillo == lodo, false},
      {"colores: uno por terreno", Enum.count(colores), 5}
    ]
  end

  defp caso_una_casilla do
    mapa = %{celdas: %{{0, 0} => "S"}, filas: 1, columnas: 1, inicio: {0, 0}, meta: {0, 0}}
    indice = %{"S" => Terreno.crear("S", "inicio", true, 0)}
    ruta = Pruebas.temporal("una_casilla.svg")
    Svg.escribir_ruta(ruta, mapa, indice, %Recorrido{posiciones: [{0, 0}], energia: 0})
    svg = File.read!(ruta)

    [contiene("una casilla: línea", svg, "<polyline"), cierra("una casilla: cierre", svg)]
  end

  # -----------------------------------
  # mejor_plan.svg
  # -----------------------------------

  defp casos_gantt do
    ruta = Pruebas.temporal("mejor_plan.svg")
    Svg.escribir_gantt(ruta, plan_ejemplo(), tareas_ejemplo())
    svg = File.read!(ruta)

    [
      abre("gantt: encabezado XML", svg),
      cierra("gantt: cierre", svg),
      contiene("gantt: duración y penalización", svg, "Duración total: 10 | Penalización: 4"),
      {"gantt: tareas a tiempo", Pruebas.ocurrencias(svg, "class=\"a-tiempo\""), 2},
      {"gantt: tareas tarde", Pruebas.ocurrencias(svg, "class=\"tarde\""), 2},
      contiene("gantt: retraso de C", svg, "fuera de plazo (+3)"),
      contiene("gantt: retraso de D", svg, "fuera de plazo (+1)"),
      contiene("gantt: barra de A proporcional", svg, "width=\"180\" height=\"24\""),
      contiene("gantt: barra de D proporcional", svg, "width=\"60\" height=\"24\""),
      contiene("gantt: eje", svg, "Tiempo en unidades")
    ]
  end

  defp caso_gantt_sin_plan do
    ruta = Pruebas.temporal("sin_plan.svg")
    Svg.escribir_gantt(ruta, nil, [])
    svg = File.read!(ruta)

    [
      contiene("sin plan: leyenda", svg, "Sin plan"),
      no_contiene("sin plan: sin barras", svg, "class=\"tarde\""),
      cierra("sin plan: cierre", svg)
    ]
  end

  defp caso_gantt_escape do
    ruta = Pruebas.temporal("gantt_escape.svg")
    plan = %Plan{orden: ["A&B"], finalizaciones: [{"A&B", 0, 2}], penalizacion: 0}
    Svg.escribir_gantt(ruta, plan, [Tarea.crear("A&B", 2, 5, [])])
    svg = File.read!(ruta)

    [
      contiene("gantt escape: ID escapado", svg, "A&amp;B"),
      no_contiene("gantt escape: sin texto crudo", svg, "A&B<")
    ]
  end

  defp caso_gantt_una_tarea do
    ruta = Pruebas.temporal("una_tarea.svg")
    plan = %Plan{orden: ["Z"], finalizaciones: [{"Z", 0, 1}], penalizacion: 1}
    Svg.escribir_gantt(ruta, plan, [Tarea.crear("Z", 1, 0, [])])
    svg = File.read!(ruta)

    [
      {"una tarea: fuera de plazo", Pruebas.ocurrencias(svg, "class=\"tarde\""), 1},
      contiene("una tarea: retraso", svg, "fuera de plazo (+1)")
    ]
  end
end

PruebasSvg.main()
