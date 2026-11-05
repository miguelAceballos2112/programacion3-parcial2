# Pruebas de ValidadorEdificio y ValidadorTareas.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_validadores.exs

defmodule PruebasValidadores do
  def main do
    casos =
      casos_terrenos() ++
        casos_cuadricula() ++
        casos_bateria() ++
        casos_ids() ++
        casos_valores() ++
        casos_dependencias() ++
        casos_ciclos()

    Pruebas.ejecutar(casos)
  end

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

  # -----------------------------------
  # Terrenos
  # -----------------------------------

  defp casos_terrenos do
    fila = [
      {1, ["X", "X", "X", "X"]},
      {2, ["X", "S", "M", "X"]},
      {3, ["X", "X", "X", "X"]}
    ]

    base = [
      {1, Terreno.crear("X", "pared", "no", 0)},
      {2, Terreno.crear("S", "inicio", "si", 0)},
      {3, Terreno.crear("M", "meta", "si", 1)}
    ]

    [
      {"terrenos: S y X pueden costar 0", ValidadorEdificio.validar(fila, base), []},
      {
        "terrenos: símbolo repetido",
        ValidadorEdificio.validar(fila, base ++ [{4, Terreno.crear("X", "muro", "no", 0)}]),
        [{4, "El símbolo X está repetido en terrenos.csv"}]
      },
      {
        "terrenos: transitable distinto de S con costo 0",
        ValidadorEdificio.validar(fila, base ++ [{4, Terreno.crear(".", "pasillo", "si", 0)}]),
        [{4, "El terreno transitable . debe tener costo positivo"}]
      },
      {
        "terrenos: costo negativo",
        ValidadorEdificio.validar(fila, base ++ [{4, Terreno.crear(".", "pasillo", "si", -1)}]),
        [{4, "El costo de . debe ser un entero no negativo y se encontró: -1"}]
      },
      {
        "terrenos: costo que no es número",
        ValidadorEdificio.validar(
          fila,
          base ++ [{4, Terreno.crear(".", "pasillo", "si", "abc")}]
        ),
        [{4, "El costo de . debe ser un entero no negativo y se encontró: abc"}]
      },
      {
        "terrenos: transitable inválido",
        ValidadorEdificio.validar(
          fila,
          base ++ [{4, Terreno.crear(".", "pasillo", "tal vez", 1)}]
        ),
        [{4, "El campo transitable de . debe ser si o no y se encontró: tal vez"}]
      }
    ]
  end

  # -----------------------------------
  # Cuadrícula
  # -----------------------------------

  defp casos_cuadricula do
    [
      {"edificio: ejemplo del enunciado es válido",
       ValidadorEdificio.validar(edificio(), terrenos()), []},
      {
        "edificio: cuadrícula vacía reporta un solo error",
        ValidadorEdificio.validar([], terrenos()),
        [{"general", "La cuadrícula está vacía"}]
      },
      {
        "edificio: fila irregular usa la línea física",
        ValidadorEdificio.validar(
          [
            {3, ["X", "X", "X", "X"]},
            {7, ["X", "S", "M", "X", "X"]},
            {9, ["X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [{7, "La fila tiene 5 columnas y se esperaban 4"}]
      },
      {
        "edificio: símbolo no definido usa la coordenada",
        ValidadorEdificio.validar(
          [
            {1, ["X", "X", "X", "X", "X"]},
            {2, ["X", "S", "Q", "M", "X"]},
            {3, ["X", "X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [{{1, 2}, "El símbolo Q no está definido en terrenos.csv"}]
      },
      {
        "edificio: dos S",
        ValidadorEdificio.validar(
          [
            {1, ["X", "X", "X", "X", "X"]},
            {2, ["X", "S", "S", "M", "X"]},
            {3, ["X", "X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [
          {{1, 1}, "Debe existir una sola casilla S"},
          {{1, 2}, "Debe existir una sola casilla S"}
        ]
      },
      {
        "edificio: sin M",
        ValidadorEdificio.validar(
          [
            {1, ["X", "X", "X", "X"]},
            {2, ["X", "S", ".", "X"]},
            {3, ["X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [{"general", "No existe ninguna casilla M"}]
      },
      {
        "edificio: esquina abierta se reporta una sola vez",
        ValidadorEdificio.validar(
          [
            {1, [".", "X", "X", "X"]},
            {2, ["X", "S", "M", "X"]},
            {3, ["X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [{{0, 0}, "El borde debe ser X y se encontró: ."}]
      },
      {
        "edificio: S en el borde reporta el borde",
        ValidadorEdificio.validar(
          [
            {1, ["X", "X", "X", "X"]},
            {2, ["S", ".", "M", "X"]},
            {3, ["X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [{{1, 0}, "El borde debe ser X y se encontró: S"}]
      },
      {
        "edificio: reporta todos los errores, no solo el primero",
        ValidadorEdificio.validar(
          [
            {1, ["X", "X", "X", "X", "X"]},
            {2, ["X", "S", "S", "Q", "X"]},
            {3, ["X", ".", ".", "X"]},
            {4, ["X", ".", ".", ".", "."]},
            {5, ["X", "X", "X", "X", "X"]}
          ],
          terrenos()
        ),
        [
          {3, "La fila tiene 4 columnas y se esperaban 5"},
          {{1, 3}, "El símbolo Q no está definido en terrenos.csv"},
          {{1, 1}, "Debe existir una sola casilla S"},
          {{1, 2}, "Debe existir una sola casilla S"},
          {"general", "No existe ninguna casilla M"},
          {{3, 4}, "El borde debe ser X y se encontró: ."}
        ]
      }
    ]
  end

  # -----------------------------------
  # Batería
  # -----------------------------------

  defp casos_bateria do
    [
      {"batería: entero positivo", ValidadorEdificio.validar_bateria([{1, "10"}]), []},
      {"batería: con espacios y en otra línea", ValidadorEdificio.validar_bateria([{3, " 10 "}]),
       []},
      {
        "batería: sin datos",
        ValidadorEdificio.validar_bateria([]),
        [{"general", "bateria.txt no tiene datos"}]
      },
      {
        "batería: cero",
        ValidadorEdificio.validar_bateria([{1, "0"}]),
        [{1, "La batería debe ser un entero positivo y se encontró: 0"}]
      },
      {
        "batería: negativo",
        ValidadorEdificio.validar_bateria([{1, "-5"}]),
        [{1, "La batería debe ser un entero positivo y se encontró: -5"}]
      },
      {
        "batería: texto",
        ValidadorEdificio.validar_bateria([{1, "abc"}]),
        [{1, "La batería debe ser un entero positivo y se encontró: abc"}]
      },
      {
        "batería: número seguido de texto",
        ValidadorEdificio.validar_bateria([{1, "10abc"}]),
        [{1, "La batería debe ser un entero positivo y se encontró: 10abc"}]
      },
      {
        "batería: decimal",
        ValidadorEdificio.validar_bateria([{1, "10.5"}]),
        [{1, "La batería debe ser un entero positivo y se encontró: 10.5"}]
      },
      {
        "batería: dos números en una línea",
        ValidadorEdificio.validar_bateria([{1, "10 20"}]),
        [{1, "La batería debe ser un entero positivo y se encontró: 10 20"}]
      },
      {
        "batería: dos líneas de datos",
        ValidadorEdificio.validar_bateria([{1, "10"}, {2, "20"}]),
        [{2, "bateria.txt debe tener una sola línea de datos"}]
      }
    ]
  end

  # -----------------------------------
  # IDs de tareas
  # -----------------------------------

  defp casos_ids do
    [
      {"tareas: ejemplo del enunciado es válido", ValidadorTareas.validar(tareas()), []},
      {"tareas: sin tareas no es un error", ValidadorTareas.validar([]), []},
      {
        "tareas: ID duplicado",
        ValidadorTareas.validar([tarea(1, "A", []), tarea(2, "A", [])]),
        [{2, "El ID A está duplicado"}]
      },
      {
        "tareas: ID con ;",
        ValidadorTareas.validar([tarea(1, "A;B", [])]),
        [{1, "El ID A;B no puede contener ; ni |"}]
      },
      {
        "tareas: ID con |",
        ValidadorTareas.validar([tarea(1, "A|B", [])]),
        [{1, "El ID A|B no puede contener ; ni |"}]
      },
      {
        "tareas: ID vacío",
        ValidadorTareas.validar([tarea(1, "", [])]),
        [{1, "La tarea no tiene ID"}]
      }
    ]
  end

  # -----------------------------------
  # Duración y plazo
  # -----------------------------------

  defp casos_valores do
    [
      {
        "tareas: duración cero",
        ValidadorTareas.validar([{1, Tarea.crear("A", 0, 1, [])}]),
        [{1, "La duración de A debe ser un entero positivo y se encontró: 0"}]
      },
      {
        "tareas: duración que no es número",
        ValidadorTareas.validar([{1, Tarea.crear("A", "abc", 1, [])}]),
        [{1, "La duración de A debe ser un entero positivo y se encontró: abc"}]
      },
      {"tareas: plazo cero es válido", ValidadorTareas.validar([{1, Tarea.crear("A", 1, 0, [])}]),
       []},
      {
        "tareas: plazo negativo",
        ValidadorTareas.validar([{1, Tarea.crear("A", 1, -1, [])}]),
        [{1, "El plazo de A debe ser un entero no negativo y se encontró: -1"}]
      },
      {
        "tareas: valor inválido no genera dependencia falsa",
        ValidadorTareas.validar([{1, Tarea.crear("B", "abc", 5, [])}, tarea(2, "D", ["B"])]),
        [{1, "La duración de B debe ser un entero positivo y se encontró: abc"}]
      }
    ]
  end

  # -----------------------------------
  # Dependencias
  # -----------------------------------

  defp casos_dependencias do
    [
      {
        "dependencias: repetida",
        ValidadorTareas.validar([tarea(1, "A", []), tarea(2, "B", ["A", "A"])]),
        [{2, "La tarea B repite la dependencia A"}]
      },
      {
        "dependencias: desconocida",
        ValidadorTareas.validar([tarea(1, "A", ["Z"])]),
        [{1, "La tarea A depende de Z, que no existe"}]
      },
      {
        "dependencias: autodependencia no se cuenta como ciclo",
        ValidadorTareas.validar([tarea(1, "A", ["A"])]),
        [{1, "La tarea A depende de sí misma"}]
      },
      {
        "dependencias: desconocida repetida se reporta una vez cada problema",
        ValidadorTareas.validar([tarea(1, "A", ["Z", "Z"])]),
        [
          {1, "La tarea A depende de Z, que no existe"},
          {1, "La tarea A repite la dependencia Z"}
        ]
      }
    ]
  end

  # -----------------------------------
  # Ciclos
  # -----------------------------------

  defp casos_ciclos do
    [
      {
        "ciclos: dos tareas",
        ValidadorTareas.validar([tarea(1, "A", ["B"]), tarea(2, "B", ["A"])]),
        [{1, "Ciclo de dependencias: A -> B -> A"}]
      },
      {
        "ciclos: una rotación se reporta una sola vez",
        ValidadorTareas.validar([
          tarea(1, "A", ["B"]),
          tarea(2, "B", ["C"]),
          tarea(3, "C", ["A"])
        ]),
        [{1, "Ciclo de dependencias: A -> B -> C -> A"}]
      },
      {
        "ciclos: se ubica en la línea del menor ID aunque no sea la primera",
        ValidadorTareas.validar([tarea(4, "C", ["A"]), tarea(8, "A", ["C"])]),
        [{8, "Ciclo de dependencias: A -> C -> A"}]
      },
      {
        "ciclos: dos ciclos que comparten tareas",
        ValidadorTareas.validar([
          tarea(1, "A", ["B", "C"]),
          tarea(2, "B", ["D"]),
          tarea(3, "C", ["D"]),
          tarea(4, "D", ["A"])
        ]),
        [
          {1, "Ciclo de dependencias: A -> B -> D -> A"},
          {1, "Ciclo de dependencias: A -> C -> D -> A"}
        ]
      },
      {
        "ciclos: mismas tareas en sentido contrario son ciclos distintos (5 en total)",
        ValidadorTareas.validar([
          tarea(1, "A", ["B", "C"]),
          tarea(2, "B", ["A", "C"]),
          tarea(3, "C", ["A", "B"])
        ]),
        [
          {1, "Ciclo de dependencias: A -> B -> A"},
          {1, "Ciclo de dependencias: A -> B -> C -> A"},
          {2, "Ciclo de dependencias: B -> C -> B"},
          {1, "Ciclo de dependencias: A -> C -> A"},
          {1, "Ciclo de dependencias: A -> C -> B -> A"}
        ]
      },
      {
        "ciclos: dependencia repetida no duplica el ciclo",
        ValidadorTareas.validar([tarea(1, "A", ["B", "B"]), tarea(2, "B", ["A"])]),
        [
          {1, "La tarea A repite la dependencia B"},
          {1, "Ciclo de dependencias: A -> B -> A"}
        ]
      },
      {
        "ciclos: dependencia desconocida no interrumpe la búsqueda",
        ValidadorTareas.validar([tarea(1, "A", ["Z", "B"]), tarea(2, "B", ["A"])]),
        [
          {1, "La tarea A depende de Z, que no existe"},
          {1, "Ciclo de dependencias: A -> B -> A"}
        ]
      },
      {
        "ciclos: tarea que depende de un ciclo no pertenece a él",
        ValidadorTareas.validar([
          tarea(1, "A", ["B"]),
          tarea(2, "B", ["A"]),
          tarea(3, "C", ["A"])
        ]),
        [{1, "Ciclo de dependencias: A -> B -> A"}]
      },
      {
        "ciclos: un rombo sin ciclos es válido",
        ValidadorTareas.validar([
          tarea(1, "A", []),
          tarea(2, "B", ["A"]),
          tarea(3, "C", ["A"]),
          tarea(4, "D", ["B", "C"])
        ]),
        []
      }
    ]
  end
end

PruebasValidadores.main()
