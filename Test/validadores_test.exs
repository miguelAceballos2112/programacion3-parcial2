defmodule ValidadoresTest do
  use ExUnit.Case, async: true

  # -----------------------------------
  # Datos de apoyo
  # -----------------------------------

  # Tabla de terrenos del enunciado
  defp terrenos do
    [
      {1, Terreno.crear("X", "pared", "no", 0)},
      {2, Terreno.crear(".", "pasillo", "si", 1)},
      {3, Terreno.crear("L", "lodo", "si", 3)},
      {4, Terreno.crear("S", "inicio", "si", 0)},
      {5, Terreno.crear("M", "meta", "si", 1)}
    ]
  end

  # Edificio del enunciado
  defp edificio do
    [
      {1, ["X", "X", "X", "X", "X", "X"]},
      {2, ["X", "S", ".", "L", "M", "X"]},
      {3, ["X", ".", "X", ".", ".", "X"]},
      {4, ["X", ".", ".", ".", ".", "X"]},
      {5, ["X", "X", "X", "X", "X", "X"]}
    ]
  end

  # Tareas del enunciado
  defp tareas do
    [
      {2, Tarea.crear("A", 3, 4, [])},
      {3, Tarea.crear("B", 2, 5, ["A"])},
      {4, Tarea.crear("C", 4, 6, ["A"])},
      {5, Tarea.crear("D", 1, 9, ["B", "C"])}
    ]
  end

  # Tarea válida con las dependencias indicadas, para probar solo los ciclos
  defp tarea(linea, id, dependencias), do: {linea, Tarea.crear(id, 1, 1, dependencias)}

  # Edificio mínimo y sus terrenos, para probar solo la tabla de terrenos
  defp edificio_minimo do
    [
      {1, ["X", "X", "X", "X"]},
      {2, ["X", "S", "M", "X"]},
      {3, ["X", "X", "X", "X"]}
    ]
  end

  defp terrenos_minimos do
    [
      {1, Terreno.crear("X", "pared", "no", 0)},
      {2, Terreno.crear("S", "inicio", "si", 0)},
      {3, Terreno.crear("M", "meta", "si", 1)}
    ]
  end

  defp validar_con_terreno(terreno) do
    ValidadorEdificio.validar(edificio_minimo(), terrenos_minimos() ++ [{4, terreno}])
  end

  # -----------------------------------
  # Terrenos
  # -----------------------------------

  test "terrenos: S y X pueden costar 0" do
    assert ValidadorEdificio.validar(edificio_minimo(), terrenos_minimos()) == []
  end

  test "terrenos: símbolo repetido" do
    assert validar_con_terreno(Terreno.crear("X", "muro", "no", 0)) ==
             [{4, "El símbolo X está repetido en terrenos.csv"}]
  end

  test "terrenos: transitable distinto de S con costo 0" do
    assert validar_con_terreno(Terreno.crear(".", "pasillo", "si", 0)) ==
             [{4, "El terreno transitable . debe tener costo positivo"}]
  end

  test "terrenos: costo negativo" do
    assert validar_con_terreno(Terreno.crear(".", "pasillo", "si", -1)) ==
             [{4, "El costo de . debe ser un entero no negativo y se encontró: -1"}]
  end

  test "terrenos: costo que no es número" do
    assert validar_con_terreno(Terreno.crear(".", "pasillo", "si", "abc")) ==
             [{4, "El costo de . debe ser un entero no negativo y se encontró: abc"}]
  end

  test "terrenos: transitable inválido" do
    assert validar_con_terreno(Terreno.crear(".", "pasillo", "tal vez", 1)) ==
             [{4, "El campo transitable de . debe ser si o no y se encontró: tal vez"}]
  end

  # -----------------------------------
  # Cuadrícula
  # -----------------------------------

  test "edificio: ejemplo del enunciado es válido" do
    assert ValidadorEdificio.validar(edificio(), terrenos()) == []
  end

  test "edificio: cuadrícula vacía reporta un solo error" do
    assert ValidadorEdificio.validar([], terrenos()) == [{"general", "La cuadrícula está vacía"}]
  end

  test "edificio: fila irregular usa la línea física" do
    filas = [
      {3, ["X", "X", "X", "X"]},
      {7, ["X", "S", "M", "X", "X"]},
      {9, ["X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) ==
             [{7, "La fila tiene 5 columnas y se esperaban 4"}]
  end

  test "edificio: símbolo no definido usa la coordenada" do
    filas = [
      {1, ["X", "X", "X", "X", "X"]},
      {2, ["X", "S", "Q", "M", "X"]},
      {3, ["X", "X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) ==
             [{{1, 2}, "El símbolo Q no está definido en terrenos.csv"}]
  end

  test "edificio: dos S" do
    filas = [
      {1, ["X", "X", "X", "X", "X"]},
      {2, ["X", "S", "S", "M", "X"]},
      {3, ["X", "X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) == [
             {{1, 1}, "Debe existir una sola casilla S"},
             {{1, 2}, "Debe existir una sola casilla S"}
           ]
  end

  test "edificio: sin M" do
    filas = [
      {1, ["X", "X", "X", "X"]},
      {2, ["X", "S", ".", "X"]},
      {3, ["X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) ==
             [{"general", "No existe ninguna casilla M"}]
  end

  test "edificio: esquina abierta se reporta una sola vez" do
    filas = [
      {1, [".", "X", "X", "X"]},
      {2, ["X", "S", "M", "X"]},
      {3, ["X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) ==
             [{{0, 0}, "El borde debe ser X y se encontró: ."}]
  end

  test "edificio: S en el borde reporta el borde" do
    filas = [
      {1, ["X", "X", "X", "X"]},
      {2, ["S", ".", "M", "X"]},
      {3, ["X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) ==
             [{{1, 0}, "El borde debe ser X y se encontró: S"}]
  end

  test "edificio: reporta todos los errores, no solo el primero" do
    filas = [
      {1, ["X", "X", "X", "X", "X"]},
      {2, ["X", "S", "S", "Q", "X"]},
      {3, ["X", ".", ".", "X"]},
      {4, ["X", ".", ".", ".", "."]},
      {5, ["X", "X", "X", "X", "X"]}
    ]

    assert ValidadorEdificio.validar(filas, terrenos()) == [
             {3, "La fila tiene 4 columnas y se esperaban 5"},
             {{1, 3}, "El símbolo Q no está definido en terrenos.csv"},
             {{1, 1}, "Debe existir una sola casilla S"},
             {{1, 2}, "Debe existir una sola casilla S"},
             {"general", "No existe ninguna casilla M"},
             {{3, 4}, "El borde debe ser X y se encontró: ."}
           ]
  end

  # -----------------------------------
  # Batería
  # -----------------------------------

  test "batería: entero positivo" do
    assert ValidadorEdificio.validar_bateria([{1, "10"}]) == []
  end

  test "batería: con espacios y en otra línea" do
    assert ValidadorEdificio.validar_bateria([{3, " 10 "}]) == []
  end

  test "batería: sin datos" do
    assert ValidadorEdificio.validar_bateria([]) == [{"general", "bateria.txt no tiene datos"}]
  end

  test "batería: valores que no son enteros positivos" do
    for valor <- ["0", "-5", "abc", "10abc", "10.5", "10 20"] do
      assert ValidadorEdificio.validar_bateria([{1, valor}]) ==
               [{1, "La batería debe ser un entero positivo y se encontró: #{valor}"}]
    end
  end

  test "batería: dos líneas de datos" do
    assert ValidadorEdificio.validar_bateria([{1, "10"}, {2, "20"}]) ==
             [{2, "bateria.txt debe tener una sola línea de datos"}]
  end

  # -----------------------------------
  # IDs de tareas
  # -----------------------------------

  test "tareas: ejemplo del enunciado es válido" do
    assert ValidadorTareas.validar(tareas()) == []
  end

  test "tareas: sin tareas no es un error" do
    assert ValidadorTareas.validar([]) == []
  end

  test "tareas: ID duplicado" do
    assert ValidadorTareas.validar([tarea(1, "A", []), tarea(2, "A", [])]) ==
             [{2, "El ID A está duplicado"}]
  end

  test "tareas: ID con ;" do
    assert ValidadorTareas.validar([tarea(1, "A;B", [])]) ==
             [{1, "El ID A;B no puede contener ; ni |"}]
  end

  test "tareas: ID con |" do
    assert ValidadorTareas.validar([tarea(1, "A|B", [])]) ==
             [{1, "El ID A|B no puede contener ; ni |"}]
  end

  test "tareas: ID vacío" do
    assert ValidadorTareas.validar([tarea(1, "", [])]) == [{1, "La tarea no tiene ID"}]
  end

  # -----------------------------------
  # Duración y plazo
  # -----------------------------------

  test "tareas: duración cero" do
    assert ValidadorTareas.validar([{1, Tarea.crear("A", 0, 1, [])}]) ==
             [{1, "La duración de A debe ser un entero positivo y se encontró: 0"}]
  end

  test "tareas: duración que no es número" do
    assert ValidadorTareas.validar([{1, Tarea.crear("A", "abc", 1, [])}]) ==
             [{1, "La duración de A debe ser un entero positivo y se encontró: abc"}]
  end

  test "tareas: plazo cero es válido" do
    assert ValidadorTareas.validar([{1, Tarea.crear("A", 1, 0, [])}]) == []
  end

  test "tareas: plazo negativo" do
    assert ValidadorTareas.validar([{1, Tarea.crear("A", 1, -1, [])}]) ==
             [{1, "El plazo de A debe ser un entero no negativo y se encontró: -1"}]
  end

  test "tareas: valor inválido no genera dependencia falsa" do
    assert ValidadorTareas.validar([{1, Tarea.crear("B", "abc", 5, [])}, tarea(2, "D", ["B"])]) ==
             [{1, "La duración de B debe ser un entero positivo y se encontró: abc"}]
  end

  # -----------------------------------
  # Dependencias
  # -----------------------------------

  test "dependencias: repetida" do
    assert ValidadorTareas.validar([tarea(1, "A", []), tarea(2, "B", ["A", "A"])]) ==
             [{2, "La tarea B repite la dependencia A"}]
  end

  test "dependencias: desconocida" do
    assert ValidadorTareas.validar([tarea(1, "A", ["Z"])]) ==
             [{1, "La tarea A depende de Z, que no existe"}]
  end

  test "dependencias: autodependencia no se cuenta como ciclo" do
    assert ValidadorTareas.validar([tarea(1, "A", ["A"])]) ==
             [{1, "La tarea A depende de sí misma"}]
  end

  test "dependencias: desconocida repetida se reporta una vez cada problema" do
    assert ValidadorTareas.validar([tarea(1, "A", ["Z", "Z"])]) == [
             {1, "La tarea A depende de Z, que no existe"},
             {1, "La tarea A repite la dependencia Z"}
           ]
  end

  # -----------------------------------
  # Ciclos
  # -----------------------------------

  test "ciclos: dos tareas" do
    assert ValidadorTareas.validar([tarea(1, "A", ["B"]), tarea(2, "B", ["A"])]) ==
             [{1, "Ciclo de dependencias: A -> B -> A"}]
  end

  test "ciclos: una rotación se reporta una sola vez" do
    registros = [tarea(1, "A", ["B"]), tarea(2, "B", ["C"]), tarea(3, "C", ["A"])]

    assert ValidadorTareas.validar(registros) == [{1, "Ciclo de dependencias: A -> B -> C -> A"}]
  end

  test "ciclos: se ubica en la línea del menor ID aunque no sea la primera" do
    assert ValidadorTareas.validar([tarea(4, "C", ["A"]), tarea(8, "A", ["C"])]) ==
             [{8, "Ciclo de dependencias: A -> C -> A"}]
  end

  test "ciclos: dos ciclos que comparten tareas" do
    registros = [
      tarea(1, "A", ["B", "C"]),
      tarea(2, "B", ["D"]),
      tarea(3, "C", ["D"]),
      tarea(4, "D", ["A"])
    ]

    assert ValidadorTareas.validar(registros) == [
             {1, "Ciclo de dependencias: A -> B -> D -> A"},
             {1, "Ciclo de dependencias: A -> C -> D -> A"}
           ]
  end

  test "ciclos: mismas tareas en sentido contrario son ciclos distintos (5 en total)" do
    registros = [
      tarea(1, "A", ["B", "C"]),
      tarea(2, "B", ["A", "C"]),
      tarea(3, "C", ["A", "B"])
    ]

    assert ValidadorTareas.validar(registros) == [
             {1, "Ciclo de dependencias: A -> B -> A"},
             {1, "Ciclo de dependencias: A -> B -> C -> A"},
             {2, "Ciclo de dependencias: B -> C -> B"},
             {1, "Ciclo de dependencias: A -> C -> A"},
             {1, "Ciclo de dependencias: A -> C -> B -> A"}
           ]
  end

  test "ciclos: dependencia repetida no duplica el ciclo" do
    assert ValidadorTareas.validar([tarea(1, "A", ["B", "B"]), tarea(2, "B", ["A"])]) == [
             {1, "La tarea A repite la dependencia B"},
             {1, "Ciclo de dependencias: A -> B -> A"}
           ]
  end

  test "ciclos: dependencia desconocida no interrumpe la búsqueda" do
    assert ValidadorTareas.validar([tarea(1, "A", ["Z", "B"]), tarea(2, "B", ["A"])]) == [
             {1, "La tarea A depende de Z, que no existe"},
             {1, "Ciclo de dependencias: A -> B -> A"}
           ]
  end

  test "ciclos: tarea que depende de un ciclo no pertenece a él" do
    registros = [tarea(1, "A", ["B"]), tarea(2, "B", ["A"]), tarea(3, "C", ["A"])]

    assert ValidadorTareas.validar(registros) == [{1, "Ciclo de dependencias: A -> B -> A"}]
  end

  test "ciclos: un rombo sin ciclos es válido" do
    registros = [
      tarea(1, "A", []),
      tarea(2, "B", ["A"]),
      tarea(3, "C", ["A"]),
      tarea(4, "D", ["B", "C"])
    ]

    assert ValidadorTareas.validar(registros) == []
  end
end
