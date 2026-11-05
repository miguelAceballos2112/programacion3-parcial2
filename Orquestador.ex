defmodule Orquestador do
  # Flujo de los dos problemas:
  #   1. Leer con las funciones de Rol 3.
  #   2. Juntar los errores de lectura con los de validación.
  #   3. Si hay errores, pedir a Rol 3 que los escriba y detenerse.
  #   4. Si no hay errores, ejecutar el problema y escribir los resultados.
  #
  # Funciones de los compañeros que se usan aquí. Los nombres marcados con (*) vienen
  # de la lista de responsabilidades de Rol 1; los demás son una propuesta por confirmar,
  # igual que los argumentos de todas.
  #
  # Rol 3:
  #   Archivos.leer_edificio(ruta)   -> {[{linea, simbolos}], errores}
  #   Archivos.leer_terrenos(ruta)   -> {[{linea, %Terreno{}}], errores}
  #   Archivos.leer_bateria(ruta)    -> {[{linea, texto}], errores}
  #   Archivos.leer_tareas(ruta)     -> {[{linea, %Tarea{}}], errores}
  #   Archivos.escribir_validacion(ruta, errores)
  #   Archivos.escribir_rescate(salida, pasos, recorridos, matriz, terrenos) -> resumen
  #   Archivos.escribir_tareas(salida, tareas, planes)                       -> resumen
  #
  # Rol 1:
  #   Robot.stream_relajacion(edificio, energia) (*)
  #   Robot.pasos_hasta_estabilizar(stream)
  #   Robot.meta_alcanzable?(matriz, estado_final)
  #   Robot.posicion(matriz, simbolo)
  #   Robot.buscar_recorridos(matriz, terrenos, inicio, energia) (*)
  #   Planificador.generar_planes(tareas, orden, tiempo) (*)

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
    {filas, errores_edificio} = Archivos.leer_edificio(ruta_edificio)
    {terrenos, errores_terrenos} = Archivos.leer_terrenos(ruta_terrenos)
    {bateria, errores_bateria} = Archivos.leer_bateria(ruta_bateria)

    errores =
      errores_edificio ++
        errores_terrenos ++
        errores_bateria ++
        ValidadorEdificio.validar(filas, terrenos) ++
        ValidadorEdificio.validar_bateria(bateria)

    # Siempre se reemplaza para que no quede el reporte de una ejecución anterior
    Archivos.escribir_validacion("#{salida}/validacion_edificio.txt", errores)

    case errores do
      [] -> ejecutar_rescate(filas, terrenos, bateria, salida)
      _ -> detener(errores, "validacion_edificio.txt")
    end
  end

  defp ejecutar_rescate(filas, terrenos, [{_linea, texto}], salida) do
    matriz = quitar_lineas(filas)
    tabla = quitar_lineas(terrenos)
    energia = texto |> String.trim() |> String.to_integer()

    pasos =
      {matriz, tabla}
      |> Robot.stream_relajacion(energia)
      |> Robot.pasos_hasta_estabilizar()

    recorridos = enumerar_recorridos(matriz, tabla, energia, Enum.at(pasos, -1))

    salida
    |> Archivos.escribir_rescate(pasos, recorridos, matriz, tabla)
    |> Util2.mostrar(:mensaje)

    resultado_rescate(recorridos)
  end

  # Si la meta no tiene costo alcanzable se omite la enumeración, pero igual se escriben
  # las salidas: el resumen lo indica y el SVG lleva la leyenda «sin recorrido».
  defp enumerar_recorridos(matriz, tabla, energia, estado_final) do
    if Robot.meta_alcanzable?(matriz, estado_final) do
      Robot.buscar_recorridos(matriz, tabla, Robot.posicion(matriz, "S"), energia)
    else
      []
    end
  end

  defp resultado_rescate([]), do: {:ok, :sin_recorrido}
  defp resultado_rescate(_recorridos), do: {:ok, :con_recorridos}

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
    {tareas, errores_lectura} = Archivos.leer_tareas(ruta)
    errores = errores_lectura ++ ValidadorTareas.validar(tareas)

    # Siempre se reemplaza para que no quede el reporte de una ejecución anterior
    Archivos.escribir_validacion("#{salida}/validacion_tareas.txt", errores)

    case errores do
      [] -> ejecutar_tareas(quitar_lineas(tareas), salida)
      _ -> detener(errores, "validacion_tareas.txt")
    end
  end

  # Sin tareas no hay error: se reporta un proyecto vacío sin enumerar planes
  defp ejecutar_tareas([], salida) do
    salida
    |> Archivos.escribir_tareas([], [])
    |> Util2.mostrar(:mensaje)

    {:ok, :proyecto_vacio}
  end

  defp ejecutar_tareas(tareas, salida) do
    planes = Planificador.generar_planes(tareas, [], 0)

    salida
    |> Archivos.escribir_tareas(tareas, planes)
    |> Util2.mostrar(:mensaje)

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
