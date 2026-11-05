# Demostración del Rol 3 (entrada de datos, archivos y SVG progresivos).
#
# Uso, desde la carpeta del proyecto:
#
#     elixir Scripts/demo_rol3.exs
#
# Lee los archivos de ejemplo de fixtures/lector/ con el Lector real y genera todos los
# archivos de salida en la carpeta salida/. Los recorridos, los planes y los pasos de
# la relajación están escritos A MANO: sirven para ver cómo quedan los archivos y los SVG.

carpeta = "salida"
File.mkdir_p!(carpeta)
ruta = fn nombre -> Path.join(carpeta, nombre) end

IO.puts("== Lectura con File.stream!/1 ==")

{:ok, filas, errores_edificio} = Lector.leer_edificio("fixtures/lector/edificio.txt")
{:ok, registros_terrenos, errores_terrenos} = Lector.leer_terrenos("fixtures/lector/terrenos.csv")
{:ok, registros_bateria, errores_bateria} = Lector.leer_bateria("fixtures/lector/bateria.txt")
{:ok, registros_tareas, _errores_tareas} = Lector.leer_tareas("fixtures/lector/tareas.csv")

IO.puts("edificio: #{length(filas)} filas, terrenos: #{length(registros_terrenos)}, tareas: #{length(registros_tareas)}")

{:ok, bateria} = Lector.entero_bateria(registros_bateria)
mapa = Lector.construir_mapa(filas)
indice = Lector.indice_terrenos(registros_terrenos)
tareas = Enum.map(registros_tareas, fn {_linea, tarea} -> tarea end)

IO.puts("inicio: #{inspect(mapa.inicio)}, meta: #{inspect(mapa.meta)}, B = #{bateria}")

# Archivo faltante: aviso claro, sin excepción.
IO.puts("\n== Archivo faltante ==")
faltante = Lector.leer_tareas("fixtures/lector/no_existe.csv")
Salida.avisar_error_lectura(faltante)

# ---------------------------------------------------------------------------
# Problema 1: robot de rescate (recorridos de ejemplo)
# ---------------------------------------------------------------------------

IO.puts("\n== Problema 1: salidas del robot ==")

# Validación del edificio (el edificio de ejemplo es válido: sin errores de lectura).
:ok =
  Salida.escribir_validacion(
    ruta.("validacion_edificio.txt"),
    "Validación del edificio",
    errores_edificio ++ errores_terrenos ++ errores_bateria
  )

recorridos = [
  %Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}, {1, 4}], energia: 5},
  %Recorrido{
    posiciones: [{1, 1}, {1, 2}, {1, 3}, {2, 3}, {2, 4}, {1, 4}],
    energia: 7
  },
  %Recorrido{
    posiciones: [{1, 1}, {2, 1}, {3, 1}, {3, 2}, {3, 3}, {2, 3}, {2, 4}, {1, 4}],
    energia: 7
  },
  %Recorrido{
    posiciones: [{1, 1}, {2, 1}, {3, 1}, {3, 2}, {3, 3}, {2, 3}, {1, 3}, {1, 4}],
    energia: 9
  }
]

# Escritura progresiva: cada recorrido se escribe apenas llega, con id consecutivo.
dispositivo = Salida.abrir_recorridos(ruta.("recorridos_rescate.csv"))
receptor = Salida.receptor_recorridos(dispositivo, fn id, recorrido, acumulado -> [{id, recorrido} | acumulado] end)
{total, con_id} = Enum.reduce(recorridos, {0, []}, receptor)
Salida.cerrar(dispositivo)
con_id = Enum.reverse(con_id)

minimo_movimientos = con_id |> Enum.map(fn {_id, r} -> Recorrido.movimientos(r) end) |> Enum.min()
minima_energia = con_id |> Enum.map(fn {_id, r} -> r.energia end) |> Enum.min()

datos_rescate = %{
  total: total,
  bateria: bateria,
  menos_movimientos: Enum.filter(con_id, fn {_id, r} -> Recorrido.movimientos(r) == minimo_movimientos end),
  menor_energia: Enum.filter(con_id, fn {_id, r} -> r.energia == minima_energia end)
}

IO.puts("-- resumen_rescate.txt (también va a pantalla) --")
:ok = Salida.resumen_rescate(ruta.("resumen_rescate.txt"), datos_rescate)

# Pasos distintos de la relajación (ilustrativos) y su índice de estabilización.
pasos = [
  %{{1, 1} => 0},
  %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1},
  %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1, {1, 3} => 4, {3, 1} => 2}
]

:ok = Salida.escribir_expansion(ruta.("expansion_energia.txt"), pasos, 3)

# SVG: la ruta de menor energía y, aparte, el caso sin recorrido.
[{_id, optimo} | _] = datos_rescate.menor_energia
:ok = Svg.escribir_ruta(ruta.("ruta_optima.svg"), mapa, indice, optimo)
:ok = Svg.escribir_ruta(ruta.("ruta_optima_sin_recorrido.svg"), mapa, indice, nil)

# ---------------------------------------------------------------------------
# Problema 2: planificación de tareas (planes de ejemplo del enunciado)
# ---------------------------------------------------------------------------

IO.puts("\n== Problema 2: salidas de la planificación ==")

# Validación de tareas con un archivo que trae registros mal formados (errores reales del Lector).
{:ok, _validas, errores_invalidos} = Lector.leer_tareas("fixtures/lector/tareas_invalidas.csv")

:ok =
  Salida.escribir_validacion(
    ruta.("validacion_tareas.txt"),
    "Validación de tareas (archivo de prueba con registros inválidos)",
    errores_invalidos
  )

planes = [
  %Plan{
    orden: ["A", "B", "C", "D"],
    finalizaciones: [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}],
    penalizacion: 4
  },
  %Plan{
    orden: ["A", "C", "B", "D"],
    finalizaciones: [{"A", 0, 3}, {"C", 3, 7}, {"B", 7, 9}, {"D", 9, 10}],
    penalizacion: 6
  }
]

dispositivo = Salida.abrir_planes(ruta.("planes.csv"))
receptor = Salida.receptor_planes(dispositivo, fn id, plan, acumulado -> [{id, plan} | acumulado] end)
{total_planes, planes_con_id} = Enum.reduce(planes, {0, []}, receptor)
Salida.cerrar(dispositivo)
planes_con_id = Enum.reverse(planes_con_id)

penalizacion_minima = planes_con_id |> Enum.map(fn {_id, p} -> p.penalizacion end) |> Enum.min()
mejores = Enum.filter(planes_con_id, fn {_id, p} -> p.penalizacion == penalizacion_minima end)

IO.puts("-- resumen_tareas.txt (también va a pantalla) --")

:ok =
  Salida.resumen_tareas(ruta.("resumen_tareas.txt"), %{
    total: total_planes,
    vacio: false,
    penalizacion_minima: penalizacion_minima,
    mejores: mejores
  })

[{_id, mejor_plan} | _] = mejores
:ok = Svg.escribir_gantt(ruta.("mejor_plan.svg"), mejor_plan, tareas)
:ok = Svg.escribir_gantt(ruta.("mejor_plan_sin_plan.svg"), nil, [])

IO.puts("\nListo. Archivos generados en #{carpeta}/:")

carpeta
|> File.ls!()
|> Enum.sort()
|> Enum.each(fn nombre -> IO.puts("  - #{nombre}") end)

IO.puts("\nAbre los SVG en el navegador, por ejemplo: #{ruta.("ruta_optima.svg")}")
