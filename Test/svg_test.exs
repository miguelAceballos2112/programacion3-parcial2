defmodule SvgTest do
  use ExUnit.Case, async: true

  @moduletag :tmp_dir

  @fixtures Path.expand("../fixtures/lector", __DIR__)

  defp cargar do
    {:ok, filas, []} = Lector.leer_edificio(Path.join(@fixtures, "edificio.txt"))
    {:ok, terrenos, []} = Lector.leer_terrenos(Path.join(@fixtures, "terrenos.csv"))
    {Lector.construir_mapa(filas), Lector.indice_terrenos(terrenos)}
  end

  defp ocurrencias(texto, patron), do: length(String.split(texto, patron)) - 1

  # Comprueba que cada texto quepa dentro del ancho del SVG. Estima 0,5 em por carácter,
  # lo mínimo que ocupa un texto normal en una fuente sans-serif.
  defp assert_textos_caben(svg) do
    [_, ancho] = Regex.run(~r/<svg [^>]*width="(\d+)"/, svg)
    ancho = String.to_integer(ancho)

    textos =
      Regex.scan(~r/<text x="(\d+)"[^>]*font-size="(\d+)"([^>]*)>([^<]*)<\/text>/, svg)

    assert textos != []

    Enum.each(textos, fn [_, x, tamano, atributos, contenido] ->
      x = String.to_integer(x)
      px = String.length(contenido) * String.to_integer(tamano) * 0.5

      cond do
        atributos =~ ~s(text-anchor="end") ->
          assert x - px >= 0, "#{contenido} se sale por la izquierda"

        atributos =~ ~s(text-anchor="middle") ->
          assert x + px / 2 <= ancho, "#{contenido} se sale por la derecha"

        true ->
          assert x + px <= ancho, "#{contenido} se sale por la derecha"
      end
    end)
  end

  defp tareas_ejemplo do
    [
      %Tarea{id: "A", duracion: 3, plazo: 4, dependencias: []},
      %Tarea{id: "B", duracion: 2, plazo: 5, dependencias: ["A"]},
      %Tarea{id: "C", duracion: 4, plazo: 6, dependencias: ["A"]},
      %Tarea{id: "D", duracion: 1, plazo: 9, dependencias: ["B", "C"]}
    ]
  end

  defp plan_ejemplo do
    %Plan{
      orden: ["A", "B", "C", "D"],
      finalizaciones: [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}],
      penalizacion: 4
    }
  end

  # --- escapar ---------------------------------------------------------------

  test "escapar neutraliza caracteres XML" do
    assert Svg.escapar("a<b & \"c\" 'd' >") == "a&lt;b &amp; &quot;c&quot; &apos;d&apos; &gt;"
    assert Svg.escapar("normal") == "normal"
    assert Svg.escapar(42) == "42"
  end

  # --- ruta_optima.svg -------------------------------------------------------

  test "ruta_optima.svg con recorrido", %{tmp_dir: tmp} do
    {mapa, indice} = cargar()
    ruta = Path.join(tmp, "ruta_optima.svg")

    recorrido = %Recorrido{
      posiciones: [{1, 1}, {1, 2}, {2, 2}, {3, 2}, {3, 3}, {3, 4}, {2, 4}, {1, 4}],
      energia: 6
    }

    :ok = Svg.escribir_ruta(ruta, mapa, indice, recorrido)
    svg = File.read!(ruta)

    assert String.starts_with?(svg, ~s(<?xml version="1.0" encoding="UTF-8"?>))
    assert String.ends_with?(svg, "</svg>\n")
    # El mapa mide 240 px, pero la leyenda de la ruta es más ancha: 32 + 8 + 50 * 8 px
    assert svg =~ ~s(width="440" height=)
    assert_textos_caben(svg)
    assert svg =~ "<polyline"
    # centros de las 8 casillas del recorrido (casilla de 40 px: x = col*40+20, y = fila*40+20)
    assert svg =~ ~s(points="60,60 100,60 100,100 100,140 140,140 180,140 180,100 180,60")
    refute svg =~ "sin recorrido"
    assert svg =~ "Ruta de menor energía: 6 de energía, 7 movimientos"
    # 30 casillas de 40x40
    assert ocurrencias(svg, ~s(width="40" height="40")) == 30
  end

  test "ruta_optima.svg sin recorrido dibuja el mapa y la leyenda", %{tmp_dir: tmp} do
    {mapa, indice} = cargar()
    ruta = Path.join(tmp, "ruta_optima.svg")

    :ok = Svg.escribir_ruta(ruta, mapa, indice, nil)
    svg = File.read!(ruta)

    assert svg =~ "sin recorrido"
    refute svg =~ "<polyline"
    assert ocurrencias(svg, ~s(width="40" height="40")) == 30
    assert String.ends_with?(svg, "</svg>\n")
  end

  test "ruta_optima.svg escapa textos de los terrenos", %{tmp_dir: tmp} do
    {mapa, indice} = cargar()
    indice = Map.put(indice, "L", %Terreno{simbolo: "L", nombre: "lodo <&> \"feo\"", transitable: true, costo: 3})
    ruta = Path.join(tmp, "ruta_optima.svg")

    :ok = Svg.escribir_ruta(ruta, mapa, indice, nil)
    svg = File.read!(ruta)

    assert svg =~ "lodo &lt;&amp;&gt; &quot;feo&quot;"
    refute svg =~ "lodo <&>"
  end

  test "ruta_optima.svg se ensancha con el nombre largo de un terreno", %{tmp_dir: tmp} do
    {mapa, indice} = cargar()
    nombre = String.duplicate("muy largo ", 12)
    indice = Map.put(indice, "L", %Terreno{simbolo: "L", nombre: nombre, transitable: true, costo: 3})
    ruta = Path.join(tmp, "nombre_largo.svg")

    :ok = Svg.escribir_ruta(ruta, mapa, indice, nil)

    assert_textos_caben(File.read!(ruta))
  end

  test "colores: paredes en gris y símbolos con colores distintos" do
    {_mapa, indice} = cargar()
    colores = Svg.colores_terrenos(indice)
    assert colores["X"] == "#37474f"
    assert colores["."] != colores["L"]
    assert map_size(colores) == 5
  end

  test "mapa mínimo de una sola casilla (caso límite)", %{tmp_dir: tmp} do
    mapa = %{celdas: %{{0, 0} => "S"}, filas: 1, columnas: 1, inicio: {0, 0}, meta: {0, 0}}
    indice = %{"S" => %Terreno{simbolo: "S", nombre: "inicio", transitable: true, costo: 0}}
    ruta = Path.join(tmp, "uno.svg")

    :ok = Svg.escribir_ruta(ruta, mapa, indice, %Recorrido{posiciones: [{0, 0}], energia: 0})
    svg = File.read!(ruta)
    assert svg =~ "<polyline"
    assert String.ends_with?(svg, "</svg>\n")
  end

  # --- mejor_plan.svg --------------------------------------------------------

  test "mejor_plan.svg: Gantt con tareas a tiempo y fuera de plazo", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "mejor_plan.svg")
    :ok = Svg.escribir_gantt(ruta, plan_ejemplo(), tareas_ejemplo())
    svg = File.read!(ruta)

    assert String.starts_with?(svg, ~s(<?xml version="1.0" encoding="UTF-8"?>))
    assert String.ends_with?(svg, "</svg>\n")
    assert svg =~ "Duración total: 10 | Penalización: 4"
    assert ocurrencias(svg, ~s(class="a-tiempo")) == 2
    assert ocurrencias(svg, ~s(class="tarde")) == 2
    assert svg =~ "fuera de plazo (+3)"
    assert svg =~ "fuera de plazo (+1)"
    # longitud proporcional: escala 60 px/unidad -> A (3 u) mide 180 px y D (1 u) mide 60 px
    assert svg =~ ~s(width="180" height="24")
    assert svg =~ ~s(width="60" height="24")
    assert svg =~ ~s(Tiempo en unidades)
    assert_textos_caben(svg)
  end

  test "mejor_plan.svg deja espacio para IDs largos y un título largo", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "largos.svg")
    ids = for i <- 1..12, do: "Implementar_modulo_#{i}"

    finalizaciones =
      ids
      |> Enum.with_index()
      |> Enum.map(fn {id, i} -> {id, i, i + 1} end)

    plan = %Plan{orden: ids, finalizaciones: finalizaciones, penalizacion: 66}
    tareas = Enum.map(ids, fn id -> %Tarea{id: id, duracion: 1, plazo: 1, dependencias: []} end)

    :ok = Svg.escribir_gantt(ruta, plan, tareas)

    assert_textos_caben(File.read!(ruta))
  end

  test "mejor_plan.svg sin plan muestra una leyenda explicativa", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "sin_plan.svg")
    :ok = Svg.escribir_gantt(ruta, nil, [])
    svg = File.read!(ruta)
    assert svg =~ "Sin plan"
    refute svg =~ ~s(class="tarde")
    assert String.ends_with?(svg, "</svg>\n")
  end

  test "mejor_plan.svg escapa IDs con caracteres XML", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "escape.svg")
    plan = %Plan{orden: ["A&B"], finalizaciones: [{"A&B", 0, 2}], penalizacion: 0}
    tareas = [%Tarea{id: "A&B", duracion: 2, plazo: 5, dependencias: []}]

    :ok = Svg.escribir_gantt(ruta, plan, tareas)
    svg = File.read!(ruta)
    assert svg =~ "A&amp;B"
    refute svg =~ "A&B<"
  end

  test "mejor_plan.svg con una sola tarea y plazo cero (límite)", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "una.svg")
    plan = %Plan{orden: ["Z"], finalizaciones: [{"Z", 0, 1}], penalizacion: 1}
    tareas = [%Tarea{id: "Z", duracion: 1, plazo: 0, dependencias: []}]

    :ok = Svg.escribir_gantt(ruta, plan, tareas)
    svg = File.read!(ruta)
    assert ocurrencias(svg, ~s(class="tarde")) == 1
    assert svg =~ "fuera de plazo (+1)"
  end
end
