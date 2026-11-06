defmodule Salida do
  @moduledoc """
  Escritura progresiva de archivos de salida (Rol 3).

  Reglas que se respetan en todo el módulo:

    * Cada archivo se crea o reemplaza (`File.open!/2` en modo `:write`).
    * Se escribe línea por línea; nunca se arma un único string con todo el contenido.
    * Los CSV usan `;` como separador y UTF-8.
    * Las coordenadas son `{fila, columna}` con origen en 0.

  ## Escritura de recorridos y planes mientras la recursión los produce

  El Rol 1 entrega cada resultado a una función receptora con acumulador. Aquí se
  construye esa función con `receptor_recorridos/2` y `receptor_planes/2`:

      dev = Salida.abrir_recorridos("salida/recorridos_rescate.csv")
      receptor = Salida.receptor_recorridos(dev, fn id, recorrido, estadisticas -> ... end)
      {total, estadisticas} = Robot.buscar_recorridos(..., {0, estadisticas_iniciales}, receptor)
      Salida.cerrar(dev)

  El acumulador es `{cantidad_escrita, estado}`; el `id` consecutivo sale de la cantidad.
  """

  # ---------------------------------------------------------------------------
  # Archivos y avisos
  # ---------------------------------------------------------------------------

  @doc """
  Abre (creando carpetas si hace falta) un archivo de salida en modo escritura UTF-8.

  Si el archivo ya existe se reemplaza. Hay que cerrarlo con `cerrar/1`.
  """
  @spec abrir(Path.t()) :: File.io_device()
  def abrir(ruta) do
    File.mkdir_p!(Path.dirname(ruta))
    File.open!(ruta, [:write, :utf8])
  end

  @doc "Cierra un archivo abierto con `abrir/1`."
  @spec cerrar(File.io_device()) :: :ok | {:error, term()}
  def cerrar(dispositivo), do: File.close(dispositivo)

  @doc """
  Muestra un aviso claro cuando falla la lectura de un archivo requerido
  (retorno `{:error, motivo, ruta}` del `Lector`), en vez de dejar una excepción.
  """
  @spec avisar_error_lectura({:error, :archivo_no_encontrado | :archivo_ilegible, Path.t()}) ::
          :ok
  def avisar_error_lectura({:error, :archivo_no_encontrado, ruta}) do
    IO.puts("ADVERTENCIA: no se encontró el archivo requerido: #{ruta}")
  end

  def avisar_error_lectura({:error, :archivo_ilegible, ruta}) do
    IO.puts("ADVERTENCIA: no se pudo leer el archivo requerido: #{ruta}")
  end

  # ---------------------------------------------------------------------------
  # recorridos_rescate.csv
  # ---------------------------------------------------------------------------

  @doc "Abre `recorridos_rescate.csv` y escribe la cabecera `id;movimientos;energia;posiciones`."
  @spec abrir_recorridos(Path.t()) :: File.io_device()
  def abrir_recorridos(ruta) do
    dispositivo = abrir(ruta)
    IO.write(dispositivo, "id;movimientos;energia;posiciones\n")
    dispositivo
  end

  @doc "Escribe una fila de recorrido. Las posiciones se muestran como `(f,c)->(f,c)->...`."
  @spec escribir_recorrido(File.io_device(), pos_integer(), Recorrido.t()) :: :ok
  def escribir_recorrido(dispositivo, id, %Recorrido{} = recorrido) do
    movimientos = Recorrido.movimientos(recorrido)
    posiciones = formatear_posiciones(recorrido.posiciones)
    IO.write(dispositivo, "#{id};#{movimientos};#{recorrido.energia};#{posiciones}\n")
  end

  @doc """
  Formatea una lista de posiciones como `(1,1)->(1,2)`.

  ## Ejemplos

      iex> Salida.formatear_posiciones([{1, 1}, {1, 2}, {2, 2}])
      "(1,1)->(1,2)->(2,2)"

      iex> Salida.formatear_posiciones([])
      ""
  """
  @spec formatear_posiciones([Recorrido.posicion()]) :: String.t()
  def formatear_posiciones(posiciones) do
    posiciones
    |> Enum.map(fn {fila, columna} -> "(#{fila},#{columna})" end)
    |> Enum.join("->")
  end

  @doc """
  Devuelve la función `fn recorrido, {n, estado} -> {n + 1, estado_nuevo} end` que
  se pasa al Rol 1. Escribe el recorrido con `id = n + 1` y llama a
  `actualizar.(id, recorrido, estado)` para mantener las estadísticas.
  """
  @spec receptor_recorridos(
          File.io_device(),
          (pos_integer(), Recorrido.t(), term() -> term())
        ) :: (Recorrido.t(), {non_neg_integer(), term()} -> {pos_integer(), term()})
  def receptor_recorridos(dispositivo, actualizar) do
    fn recorrido, {n, estado} ->
      id = n + 1
      escribir_recorrido(dispositivo, id, recorrido)
      {id, actualizar.(id, recorrido, estado)}
    end
  end

  # ---------------------------------------------------------------------------
  # planes.csv
  # ---------------------------------------------------------------------------

  @doc "Abre `planes.csv` y escribe la cabecera `id;orden;duracion_total;penalizacion`."
  @spec abrir_planes(Path.t()) :: File.io_device()
  def abrir_planes(ruta) do
    dispositivo = abrir(ruta)
    IO.write(dispositivo, "id;orden;duracion_total;penalizacion\n")
    dispositivo
  end

  @doc "Escribe una fila de plan. Los IDs del orden se separan con ` → `."
  @spec escribir_plan(File.io_device(), pos_integer(), Plan.t()) :: :ok
  def escribir_plan(dispositivo, id, %Plan{} = plan) do
    orden = Enum.join(plan.orden, " → ")
    IO.write(dispositivo, "#{id};#{orden};#{Plan.duracion_total(plan)};#{plan.penalizacion}\n")
  end

  @doc "Igual que `receptor_recorridos/2`, pero para planes."
  @spec receptor_planes(File.io_device(), (pos_integer(), Plan.t(), term() -> term())) ::
          (Plan.t(), {non_neg_integer(), term()} -> {pos_integer(), term()})
  def receptor_planes(dispositivo, actualizar) do
    fn plan, {n, estado} ->
      id = n + 1
      escribir_plan(dispositivo, id, plan)
      {id, actualizar.(id, plan, estado)}
    end
  end

  # ---------------------------------------------------------------------------
  # Resúmenes (archivo + pantalla)
  # ---------------------------------------------------------------------------

  @doc """
  Escribe `resumen_rescate.txt` y lo muestra por pantalla (salvo `mostrar: false`).

  `datos` es un mapa con:

    * `:total`              - cantidad de recorridos válidos
    * `:bateria`            - presupuesto B (opcional)
    * `:menos_movimientos`  - lista de `{id, %Recorrido{}}` (con empates)
    * `:menor_energia`      - lista de `{id, %Recorrido{}}` (con empates)

  Opciones: `mostrar: false` evita imprimir por pantalla (útil en pruebas).
  """
  @spec resumen_rescate(Path.t(), map(), keyword()) :: :ok
  def resumen_rescate(ruta, datos, opciones \\ []) do
    total = Map.get(datos, :total, 0)

    cabecera =
      ["Resumen del robot de rescate"] ++
        case Map.get(datos, :bateria) do
          nil -> []
          bateria -> ["Presupuesto de energía B: #{bateria}"]
        end

    cuerpo =
      if total == 0 do
        [
          "Total de recorridos válidos: 0",
          "No existe recorrido válido que alcance la meta sin superar B."
        ]
      else
        menos = Map.get(datos, :menos_movimientos, [])
        menor = Map.get(datos, :menor_energia, [])

        [
          "Total de recorridos válidos: #{total}",
          "Recorridos con menos movimientos (#{movimientos_de(menos)} movimientos): #{length(menos)}"
        ] ++
          Enum.map(menos, &linea_recorrido/1) ++
          [
            "Recorridos con menor consumo (#{energia_de(menor)} de energía): #{length(menor)}"
          ] ++ Enum.map(menor, &linea_recorrido/1)
      end

    escribir_lineas(ruta, cabecera ++ cuerpo, opciones)
  end

  @doc """
  Escribe `resumen_tareas.txt` y lo muestra por pantalla (salvo `mostrar: false`).

  `datos` es un mapa con:

    * `:total`               - cantidad de planes válidos
    * `:vacio`               - `true` si no hay tareas (proyecto vacío)
    * `:penalizacion_minima` - penalización mínima
    * `:mejores`             - lista de `{id, %Plan{}}` que alcanzan el mínimo

  Opciones: `mostrar: false` evita imprimir por pantalla (útil en pruebas).
  """
  @spec resumen_tareas(Path.t(), map(), keyword()) :: :ok
  def resumen_tareas(ruta, datos, opciones \\ []) do
    total = Map.get(datos, :total, 0)
    cabecera = ["Resumen de la planificación de tareas"]

    cuerpo =
      cond do
        Map.get(datos, :vacio, false) ->
          ["Proyecto vacío: no hay tareas que planificar."]

        total == 0 ->
          ["Total de planes válidos: 0", "No existe ningún plan válido."]

        true ->
          mejores = Map.get(datos, :mejores, [])

          duracion =
            case mejores do
              [{_id, plan} | _] -> Plan.duracion_total(plan)
              [] -> 0
            end

          [
            "Total de planes válidos: #{total}",
            "Tiempo total del proyecto: #{duracion}",
            "Penalización mínima: #{Map.get(datos, :penalizacion_minima)}",
            "Planes que alcanzan la penalización mínima: #{length(mejores)}"
          ] ++ Enum.map(mejores, &linea_plan/1)
      end

    escribir_lineas(ruta, cabecera ++ cuerpo, opciones)
  end

  defp movimientos_de([{_id, recorrido} | _]), do: Recorrido.movimientos(recorrido)
  defp movimientos_de([]), do: 0

  defp energia_de([{_id, recorrido} | _]), do: recorrido.energia
  defp energia_de([]), do: 0

  defp linea_recorrido({id, %Recorrido{} = recorrido}) do
    "  ##{id}: #{formatear_posiciones(recorrido.posiciones)} " <>
      "| movimientos=#{Recorrido.movimientos(recorrido)} | energía=#{recorrido.energia}"
  end

  defp linea_plan({id, %Plan{} = plan}) do
    "  ##{id}: #{Enum.join(plan.orden, " → ")} " <>
      "| duración=#{Plan.duracion_total(plan)} | penalización=#{plan.penalizacion}"
  end

  defp escribir_lineas(ruta, lineas, opciones) do
    mostrar = Keyword.get(opciones, :mostrar, true)
    dispositivo = abrir(ruta)

    try do
      Enum.each(lineas, fn linea ->
        IO.write(dispositivo, linea <> "\n")
        if mostrar, do: IO.puts(linea)
      end)
    after
      cerrar(dispositivo)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # expansion_energia.txt
  # ---------------------------------------------------------------------------

  @doc """
  Escribe `expansion_energia.txt`.

  `pasos` es una lista de mapas `%{{fila, col} => costo}` (los pasos distintos de la
  relajación, en orden); `indice` es el índice de estabilización. Las posiciones de
  cada paso se escriben ordenadas por fila y columna.
  """
  @spec escribir_expansion(Path.t(), [map()], integer()) :: :ok
  def escribir_expansion(ruta, pasos, indice) do
    dispositivo = abrir(ruta)

    try do
      pasos
      |> Enum.with_index()
      |> Enum.each(fn {mapa, i} ->
        IO.write(dispositivo, "Paso #{i}:\n")

        mapa
        |> Enum.sort()
        |> Enum.each(fn {{fila, columna}, costo} ->
          IO.write(dispositivo, "  (#{fila},#{columna}) = #{costo}\n")
        end)
      end)

      IO.write(dispositivo, "Índice de estabilización: #{indice}\n")
    after
      cerrar(dispositivo)
    end

    :ok
  end

  # ---------------------------------------------------------------------------
  # validacion_edificio.txt / validacion_tareas.txt
  # ---------------------------------------------------------------------------

  @doc """
  Escribe un archivo de validación con todos los errores.

  `errores` es una lista de `{ubicacion, mensaje}` donde la ubicación es un número
  de línea, una coordenada `{fila, col}` o un texto. Conviene pasar juntos los
  errores de parseo del `Lector` y los del validador.
  """
  @spec escribir_validacion(Path.t(), String.t(), [{term(), String.t()}]) :: :ok
  def escribir_validacion(ruta, titulo, errores) do
    dispositivo = abrir(ruta)

    try do
      IO.write(dispositivo, titulo <> "\n")

      case errores do
        [] ->
          IO.write(dispositivo, "Sin errores.\n")

        _ ->
          IO.write(dispositivo, "Errores encontrados: #{length(errores)}\n")

          Enum.each(errores, fn {ubicacion, mensaje} ->
            IO.write(dispositivo, "- #{formatear_ubicacion(ubicacion)}: #{mensaje}\n")
          end)
      end
    after
      cerrar(dispositivo)
    end

    :ok
  end

  defp formatear_ubicacion(linea) when is_integer(linea), do: "línea #{linea}"

  defp formatear_ubicacion({fila, columna}) when is_integer(fila) and is_integer(columna),
    do: "casilla (#{fila},#{columna})"

  defp formatear_ubicacion(texto) when is_binary(texto), do: texto
  defp formatear_ubicacion(otro), do: inspect(otro)
end
