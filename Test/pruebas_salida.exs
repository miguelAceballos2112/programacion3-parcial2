# Pruebas de Salida.
#
# Ejecución:
#   .\compilar.bat
#   elixir Test/pruebas_salida.exs

defmodule PruebasSalida do
  def main do
    casos =
      casos_recorridos() ++
        casos_planes() ++
        casos_resumen_rescate() ++
        casos_resumen_tareas() ++
        caso_expansion() ++
        casos_validacion() ++
        caso_aviso() ++
        caso_reemplazo()

    Pruebas.ejecutar(casos)
  end

  defp plan_ejemplo do
    %Plan{
      orden: ["A", "B", "C", "D"],
      finalizaciones: [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}],
      penalizacion: 4
    }
  end

  defp contiene(nombre, texto, parte), do: {nombre, Pruebas.contiene_texto?(texto, parte), true}

  # -----------------------------------
  # recorridos_rescate.csv
  # -----------------------------------

  defp casos_recorridos do
    ruta = Pruebas.temporal("carpeta_nueva/recorridos_rescate.csv")
    dispositivo = Salida.abrir_recorridos(ruta)
    receptor = Salida.receptor_recorridos(dispositivo, fn id, _recorrido, ids -> [id | ids] end)

    recorridos = [
      %Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}], energia: 5},
      %Recorrido{posiciones: [{1, 1}, {2, 1}], energia: 1}
    ]

    resultado = Enum.reduce(recorridos, {0, []}, receptor)
    Salida.cerrar(dispositivo)

    vacio = Pruebas.temporal("recorridos_vacio.csv")
    vacio |> Salida.abrir_recorridos() |> Salida.cerrar()

    [
      {"recorridos: ids consecutivos", resultado, {2, [2, 1]}},
      {"recorridos: contenido", File.read!(ruta),
       "id;movimientos;energia;posiciones\n1;2;5;(1,1)->(1,2)->(1,3)\n2;1;1;(1,1)->(2,1)\n"},
      {"recorridos: sin datos solo trae la cabecera", File.read!(vacio),
       "id;movimientos;energia;posiciones\n"},
      {"posiciones formateadas", Salida.formatear_posiciones([{1, 1}, {1, 2}, {2, 2}]),
       "(1,1)->(1,2)->(2,2)"},
      {"posiciones vacías", Salida.formatear_posiciones([]), ""}
    ]
  end

  # -----------------------------------
  # planes.csv
  # -----------------------------------

  defp casos_planes do
    ruta = Pruebas.temporal("planes.csv")
    dispositivo = Salida.abrir_planes(ruta)
    receptor = Salida.receptor_planes(dispositivo, fn _id, _plan, estado -> estado end)

    segundo = %Plan{
      orden: ["A", "C", "B", "D"],
      finalizaciones: [{"A", 0, 3}, {"C", 3, 7}, {"B", 7, 9}, {"D", 9, 10}],
      penalizacion: 6
    }

    resultado = Enum.reduce([plan_ejemplo(), segundo], {0, :ok}, receptor)
    Salida.cerrar(dispositivo)

    [
      {"planes: conteo", resultado, {2, :ok}},
      {"planes: usa ; y flecha", File.read!(ruta),
       "id;orden;duracion_total;penalizacion\n1;A → B → C → D;10;4\n2;A → C → B → D;10;6\n"},
      {"duración de plan vacío", Plan.duracion_total(%Plan{}), 0},
      {"duración de plan", Plan.duracion_total(plan_ejemplo()), 10},
      {"movimientos de recorrido vacío", Recorrido.movimientos(%Recorrido{}), 0}
    ]
  end

  # -----------------------------------
  # Resúmenes
  # -----------------------------------

  defp casos_resumen_rescate do
    ruta = Pruebas.temporal("resumen_rescate.txt")
    corto = {2, %Recorrido{posiciones: [{1, 1}, {2, 1}, {3, 1}], energia: 2}}
    datos = %{total: 3, bateria: 10, menos_movimientos: [corto], menor_energia: [corto]}

    # Este resumen también se muestra en pantalla
    Salida.resumen_rescate(ruta, datos)
    archivo = File.read!(ruta)

    sin_recorrido = Pruebas.temporal("resumen_sin_recorrido.txt")
    Salida.resumen_rescate(sin_recorrido, %{total: 0, bateria: 1}, mostrar: false)

    [
      contiene("resumen rescate: total", archivo, "Total de recorridos válidos: 3"),
      contiene("resumen rescate: B", archivo, "Presupuesto de energía B: 10"),
      contiene("resumen rescate: movimientos", archivo, "menos movimientos (2 movimientos): 1"),
      contiene("resumen rescate: energía", archivo, "menor consumo (2 de energía): 1"),
      contiene("resumen rescate: recorrido", archivo, "#2: (1,1)->(2,1)->(3,1)"),
      contiene("resumen rescate: sin recorrido", File.read!(sin_recorrido), "No existe recorrido válido")
    ]
  end

  defp casos_resumen_tareas do
    ruta = Pruebas.temporal("resumen_tareas.txt")
    datos = %{total: 2, vacio: false, penalizacion_minima: 4, mejores: [{1, plan_ejemplo()}]}
    Salida.resumen_tareas(ruta, datos, mostrar: false)
    archivo = File.read!(ruta)

    vacio = Pruebas.temporal("resumen_vacio.txt")
    Salida.resumen_tareas(vacio, %{total: 0, vacio: true}, mostrar: false)

    sin_planes = Pruebas.temporal("resumen_sin_planes.txt")
    Salida.resumen_tareas(sin_planes, %{total: 0, vacio: false}, mostrar: false)

    [
      contiene("resumen tareas: total", archivo, "Total de planes válidos: 2"),
      contiene("resumen tareas: tiempo", archivo, "Tiempo total del proyecto: 10"),
      contiene("resumen tareas: penalización", archivo, "Penalización mínima: 4"),
      contiene("resumen tareas: cantidad", archivo, "Planes que alcanzan la penalización mínima: 1"),
      contiene("resumen tareas: plan", archivo, "#1: A → B → C → D"),
      contiene("resumen tareas: vacío", File.read!(vacio), "Proyecto vacío"),
      contiene("resumen tareas: sin planes", File.read!(sin_planes), "No existe ningún plan válido")
    ]
  end

  # -----------------------------------
  # expansion_energia.txt
  # -----------------------------------

  defp caso_expansion do
    ruta = Pruebas.temporal("expansion_energia.txt")
    pasos = [%{{1, 1} => 0}, %{{1, 2} => 1, {1, 1} => 0, {0, 5} => 9}]
    Salida.escribir_expansion(ruta, pasos, 1)

    [
      {"expansión: posiciones por fila y columna", File.read!(ruta),
       "Paso 0:\n  (1,1) = 0\nPaso 1:\n  (0,5) = 9\n  (1,1) = 0\n  (1,2) = 1\nÍndice de estabilización: 1\n"}
    ]
  end

  # -----------------------------------
  # Validación, avisos y reemplazo
  # -----------------------------------

  defp casos_validacion do
    ruta = Pruebas.temporal("validacion_edificio.txt")

    errores = [
      {3, "costo no es un entero"},
      {{0, 2}, "el borde debe ser X"},
      {"general", "texto libre"}
    ]

    Salida.escribir_validacion(ruta, "Validación del edificio", errores)
    archivo = File.read!(ruta)

    sin_errores = Pruebas.temporal("validacion_tareas.txt")
    Salida.escribir_validacion(sin_errores, "Validación de tareas", [])

    [
      contiene("validación: cantidad", archivo, "Errores encontrados: 3"),
      contiene("validación: línea", archivo, "- línea 3: costo no es un entero"),
      contiene("validación: coordenada", archivo, "- casilla (0,2): el borde debe ser X"),
      contiene("validación: general", archivo, "- general: texto libre"),
      contiene("validación: sin errores", File.read!(sin_errores), "Sin errores.")
    ]
  end

  defp caso_aviso do
    resultado = Salida.avisar_error_lectura({:error, :archivo_no_encontrado, "datos/edificio.txt"})

    [{"aviso de archivo faltante sin excepción", resultado, :ok}]
  end

  defp caso_reemplazo do
    ruta = Pruebas.temporal("resumen_reemplazo.txt")
    File.write(ruta, "contenido anterior muy largo que no debe quedar")
    Salida.escribir_validacion(ruta, "T", [])

    [{"escribir reemplaza el archivo", Pruebas.contiene_texto?(File.read!(ruta), "anterior"), false}]
  end
end

PruebasSalida.main()
