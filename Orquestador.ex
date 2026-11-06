defmodule Orquestador do
  # Flujo de los dos problemas:
  #   1. Revisar que existan los archivos.
  #   2. Leer con Lector y juntar los errores de lectura con los de validación.
  #   3. Escribir el reporte de validación. Si hay errores, detenerse.
  #   4. Si no hay errores, ejecutar el problema y escribir los resultados.
  #
  # Los recorridos y los planes se escriben a medida que la recursión los produce:
  # Robot y Planificador entregan cada uno a un receptor de Salida, y en memoria solo
  # quedan las estadísticas.

  # -----------------------------------
  # Problema 1: robot de rescate
  # -----------------------------------

  # Lee de la carpeta indicada y escribe allí mismo las salidas
  def rescate(carpeta) do
    rutas = [
      "#{carpeta}/edificio.txt",
      "#{carpeta}/terrenos.csv",
      "#{carpeta}/bateria.txt"
    ]

    case archivos_faltantes(rutas) do
      [] -> validar_rescate(rutas, carpeta)
      faltantes -> avisar_faltantes(faltantes)
    end
  end

  defp validar_rescate([ruta_edificio, ruta_terrenos, ruta_bateria], salida) do
    {:ok, filas, errores_edificio} = Lector.leer_edificio(ruta_edificio)
    {:ok, terrenos, errores_terrenos} = Lector.leer_terrenos(ruta_terrenos)
    {:ok, bateria, errores_bateria} = Lector.leer_bateria(ruta_bateria)

    errores =
      errores_edificio ++
        errores_terrenos ++
        errores_bateria ++
        ValidadorEdificio.validar(filas, terrenos) ++
        ValidadorEdificio.validar_bateria(bateria)

    # Siempre se reemplaza para que no quede el reporte de una ejecución anterior
    Salida.escribir_validacion(
      "#{salida}/validacion_edificio.txt",
      "Validación del edificio",
      errores
    )

    case errores do
      [] -> ejecutar_rescate(filas, terrenos, bateria, salida)
      _ -> detener(errores, "validacion_edificio.txt")
    end
  end

  defp ejecutar_rescate(filas, terrenos, bateria, salida) do
    edificio = quitar_lineas(filas)
    tabla = Lector.indice_terrenos(terrenos)
    {:ok, energia} = Lector.entero_bateria(bateria)

    {pasos, indice} = Robot.expansion(edificio, tabla, energia)
    Salida.escribir_expansion("#{salida}/expansion_energia.txt", pasos, indice)

    estadisticas = escribir_recorridos(edificio, tabla, energia, pasos, salida)

    Salida.resumen_rescate("#{salida}/resumen_rescate.txt", %{
      total: estadisticas.total,
      bateria: energia,
      menos_movimientos: estadisticas.menos_movimientos,
      menor_energia: estadisticas.menor_energia
    })

    Svg.escribir_ruta(
      "#{salida}/ruta_optima.svg",
      Lector.construir_mapa(filas),
      tabla,
      Robot.Estadisticas.primero_menor_energia(estadisticas)
    )

    resultado_rescate(estadisticas.total)
  end

  # El CSV se crea siempre. Si la meta no tiene costo alcanzable se omite la enumeración
  # y solo queda la cabecera; el resumen y el SVG indican que no hay recorrido.
  defp escribir_recorridos(edificio, tabla, energia, pasos, salida) do
    dispositivo = Salida.abrir_recorridos("#{salida}/recorridos_rescate.csv")
    meta = Robot.ubicar(edificio, "M")
    estado_final = Enum.at(pasos, -1)

    estadisticas =
      if Robot.meta_alcanzable?({estado_final, meta}) do
        enumerar_recorridos(edificio, tabla, energia, dispositivo)
      else
        Robot.Estadisticas.nuevo()
      end

    Salida.cerrar(dispositivo)
    estadisticas
  end

  defp enumerar_recorridos(edificio, tabla, energia, dispositivo) do
    receptor =
      Salida.receptor_recorridos(dispositivo, fn _id, recorrido, estadisticas ->
        Robot.Estadisticas.actualizar(recorrido, estadisticas)
      end)

    {_total, estadisticas} =
      Robot.buscar_recorridos(
        edificio,
        tabla,
        energia,
        {0, Robot.Estadisticas.nuevo()},
        receptor
      )

    estadisticas
  end

  defp resultado_rescate(0), do: {:ok, :sin_recorrido}
  defp resultado_rescate(_total), do: {:ok, :con_recorridos}

  # -----------------------------------
  # Problema 2: planificación de tareas
  # -----------------------------------

  # Lee de la carpeta indicada y escribe allí mismo las salidas
  def tareas(carpeta) do
    ruta = "#{carpeta}/tareas.csv"

    case archivos_faltantes([ruta]) do
      [] -> validar_tareas(ruta, carpeta)
      faltantes -> avisar_faltantes(faltantes)
    end
  end

  defp validar_tareas(ruta, salida) do
    {:ok, tareas, errores_lectura} = Lector.leer_tareas(ruta)
    errores = errores_lectura ++ ValidadorTareas.validar(tareas)

    # Siempre se reemplaza para que no quede el reporte de una ejecución anterior
    Salida.escribir_validacion(
      "#{salida}/validacion_tareas.txt",
      "Validación de tareas",
      errores
    )

    case errores do
      [] -> ejecutar_tareas(quitar_lineas(tareas), salida)
      _ -> detener(errores, "validacion_tareas.txt")
    end
  end

  # Sin tareas no hay error: se reporta un proyecto vacío sin enumerar planes
  defp ejecutar_tareas([], salida) do
    "#{salida}/planes.csv"
    |> Salida.abrir_planes()
    |> Salida.cerrar()

    Salida.resumen_tareas("#{salida}/resumen_tareas.txt", %{total: 0, vacio: true})
    Svg.escribir_gantt("#{salida}/mejor_plan.svg", nil, [])

    {:ok, :proyecto_vacio}
  end

  defp ejecutar_tareas(tareas, salida) do
    dispositivo = Salida.abrir_planes("#{salida}/planes.csv")

    receptor =
      Salida.receptor_planes(dispositivo, fn _id, plan, estadisticas ->
        Planificador.Estadisticas.actualizar(plan, estadisticas)
      end)

    {_total, estadisticas} =
      Planificador.generar_planes(tareas, {0, Planificador.Estadisticas.nuevo()}, receptor)

    Salida.cerrar(dispositivo)

    Salida.resumen_tareas("#{salida}/resumen_tareas.txt", %{
      total: estadisticas.total,
      vacio: false,
      penalizacion_minima: estadisticas.penalizacion_minima,
      mejores: estadisticas.optimos
    })

    Svg.escribir_gantt(
      "#{salida}/mejor_plan.svg",
      Planificador.Estadisticas.primer_optimo(estadisticas),
      tareas
    )

    {:ok, :con_planes}
  end

  # -----------------------------------
  # Funciones auxiliares
  # -----------------------------------

  defp archivos_faltantes(rutas) do
    Util2.aplicar_filtro(rutas, &falta_archivo?/1)
  end

  # File.stream! solo falla cuando empieza a leer, por eso se pide la primera línea.
  # Así no se carga el archivo completo, como exige el enunciado.
  defp falta_archivo?(ruta) do
    try do
      ruta
      |> File.stream!()
      |> Enum.take(1)

      false
    rescue
      File.Error -> true
    end
  end

  defp avisar_faltantes(faltantes) do
    Util2.mostrar("No se encontraron estos archivos requeridos:", :error)

    faltantes
    |> Util2.convertir_coleccion_mensaje()
    |> Util2.mostrar(:error)

    {:error, :faltan_archivos}
  end

  defp detener(errores, archivo) do
    "Se encontraron #{length(errores)} errores de validación. Revise #{archivo}."
    |> Util2.mostrar(:error)

    {:error, :validacion}
  end

  defp quitar_lineas(registros) do
    Enum.map(registros, fn {_linea, registro} -> registro end)
  end
end
