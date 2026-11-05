# Pruebas de Lector.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_lector.exs

defmodule PruebasLector do
  def main do
    casos =
      casos_validos() ++
        casos_invalidos() ++
        casos_limite()

    Pruebas.ejecutar(casos)
  end

  defp fixture(nombre), do: "fixtures/lector/#{nombre}"

  defp lineas_de(errores), do: Enum.map(errores, fn {linea, _mensaje} -> linea end)

  defp ids_de(registros), do: Enum.map(registros, fn {_linea, tarea} -> tarea.id end)

  # -----------------------------------
  # Casos válidos
  # -----------------------------------

  defp casos_validos do
    {:ok, terrenos, errores_terrenos} = Lector.leer_terrenos(fixture("terrenos.csv"))
    {:ok, filas, errores_filas} = Lector.leer_edificio(fixture("edificio.txt"))
    {:ok, bateria, errores_bateria} = Lector.leer_bateria(fixture("bateria.txt"))
    {:ok, tareas, errores_tareas} = Lector.leer_tareas(fixture("tareas.csv"))
    mapa = Lector.construir_mapa(filas)
    %{{1, 3} => celda} = mapa.celdas
    %{"L" => lodo} = Lector.indice_terrenos(terrenos)

    [
      {"lineas_utiles omite comentarios y conserva la línea",
       fixture("terrenos.csv") |> Lector.lineas_utiles() |> Enum.take(1), [{2, "X,pared,no,0"}]},
      {"terrenos: sin errores", errores_terrenos, []},
      {"terrenos: cantidad", length(terrenos), 5},
      {"terrenos: primero", Enum.at(terrenos, 0), {2, Terreno.crear("X", "pared", false, 0)}},
      {"terrenos: lodo", Enum.at(terrenos, 2), {4, Terreno.crear("L", "lodo", true, 3)}},
      {"edificio: sin errores", errores_filas, []},
      {"edificio: filas", length(filas), 5},
      {"edificio: fila 1", Enum.at(filas, 0), {1, ["X", "X", "X", "X", "X", "X"]}},
      {"edificio: fila 2", Enum.at(filas, 1), {2, ["X", "S", ".", "L", "M", "X"]}},
      {"batería: registros", bateria, [{1, "10"}]},
      {"batería: sin errores", errores_bateria, []},
      {"batería: entero", Lector.entero_bateria(bateria), {:ok, 10}},
      {"tareas: sin errores", errores_tareas, []},
      {"tareas: ids", ids_de(tareas), ["A", "B", "C", "D"]},
      {"tareas: primera", Enum.at(tareas, 0), {2, Tarea.crear("A", 3, 4, [])}},
      {"tareas: dependencias", Enum.at(tareas, -1), {5, Tarea.crear("D", 1, 9, ["B", "C"])}},
      {"mapa: filas", mapa.filas, 5},
      {"mapa: columnas", mapa.columnas, 6},
      {"mapa: inicio", mapa.inicio, {1, 1}},
      {"mapa: meta", mapa.meta, {1, 4}},
      {"mapa: celda", celda, "L"},
      {"índice de terrenos", lodo.costo, 3}
    ]
  end

  # -----------------------------------
  # Casos inválidos
  # -----------------------------------

  defp casos_invalidos do
    ruta = fixture("no_existe.csv")

    casos_faltantes(ruta) ++
      caso_tareas_invalidas() ++
      caso_terrenos_invalidos() ++
      [
        {"batería: texto", Lector.entero_bateria([{1, "diez"}]), :error},
        {"batería: dos líneas", Lector.entero_bateria([{1, "10"}, {2, "20"}]), :error},
        {"batería: sin líneas", Lector.entero_bateria([]), :error}
      ]
  end

  defp casos_faltantes(ruta) do
    esperado = {:error, :archivo_no_encontrado, ruta}

    [
      {"falta tareas", Lector.leer_tareas(ruta), esperado},
      {"falta terrenos", Lector.leer_terrenos(ruta), esperado},
      {"falta edificio", Lector.leer_edificio(ruta), esperado},
      {"falta batería", Lector.leer_bateria(ruta), esperado}
    ]
  end

  # La duración que no es entera se conserva para que la reporte el validador
  defp caso_tareas_invalidas do
    {:ok, registros, errores} = Lector.leer_tareas(fixture("tareas_invalidas.csv"))

    [
      {"tareas inválidas: conserva los registros completos", ids_de(registros), ["A", "B", "D"]},
      {"tareas inválidas: líneas con error", lineas_de(errores), [4, 5]},
      {"tareas inválidas: duración como texto", Enum.at(registros, 1), {3, Tarea.crear("B", "dos", 5, ["A"])}}
    ]
  end

  # Transitable y costo se conservan; símbolo largo y campos faltantes son de lectura
  defp caso_terrenos_invalidos do
    ruta = Pruebas.temporal("terrenos_malos.csv")

    File.write(
      ruta,
      ".,pasillo,si,1\nLL,lodo,si,3\nL,lodo,tal vez,3\nP,pared,no,abc\nQ,pared,no,-2\nR,roca,no\n"
    )

    {:ok, registros, errores} = Lector.leer_terrenos(ruta)

    [
      {"terrenos inválidos: líneas con error", lineas_de(errores), [2, 6]},
      {"terrenos inválidos: transitable como texto", Enum.at(registros, 1), {3, Terreno.crear("L", "lodo", "tal vez", 3)}},
      {"terrenos inválidos: costo como texto", Enum.at(registros, 2), {4, Terreno.crear("P", "pared", false, "abc")}},
      {"terrenos inválidos: costo negativo", Enum.at(registros, 3), {5, Terreno.crear("Q", "pared", false, -2)}}
    ]
  end

  # -----------------------------------
  # Casos límite
  # -----------------------------------

  defp casos_limite do
    comentarios = Pruebas.temporal("comentarios.csv")
    File.write(comentarios, "# solo comentario\n\n   \n  # otro comentario\n")

    vacio = Pruebas.temporal("vacio.csv")
    File.write(vacio, "")

    numeracion = Pruebas.temporal("numeracion.csv")
    File.write(numeracion, "# c\n\nA;1;1;-\n   # otro\nB;1;1;A")

    bom = Pruebas.temporal("bom.txt")
    File.write(bom, "﻿10\n")

    latin1 = Pruebas.temporal("latin1.txt")
    File.write(latin1, <<"caf", 0xE9, "\n">>)

    mapa = Lector.construir_mapa([])

    [
      {"solo comentarios: tareas", Lector.leer_tareas(comentarios), {:ok, [], []}},
      {"solo comentarios: edificio", Lector.leer_edificio(comentarios), {:ok, [], []}},
      {"archivo vacío", Lector.leer_terrenos(vacio), {:ok, [], []}},
      {"la línea física cuenta comentarios y vacías", Lector.leer_tareas(numeracion),
       {:ok, [{3, Tarea.crear("A", 1, 1, [])}, {5, Tarea.crear("B", 1, 1, ["A"])}], []}},
      {"ignora el BOM", Lector.leer_bateria(bom), {:ok, [{1, "10"}], []}},
      {"convierte un archivo en Latin-1", Lector.leer_bateria(latin1), {:ok, [{1, "café"}], []}},
      {"mapa vacío: filas", mapa.filas, 0},
      {"mapa vacío: columnas", mapa.columnas, 0},
      {"mapa vacío: inicio", mapa.inicio, nil},
      {"mapa vacío: meta", mapa.meta, nil}
    ]
  end
end

PruebasLector.main()
