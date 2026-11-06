defmodule Lector do
  @moduledoc """
  Entrada de datos con Streams (Rol 3).

  Todos los archivos se leen con `File.stream!/1`, línea por línea. La limpieza
  (espacios, líneas en blanco y comentarios `#`) y la conversión a structs son
  perezosas; solo al final se acumulan los registros ya convertidos.

  ## Contrato de retorno

  Cada `leer_*` devuelve:

    * `{:ok, registros, errores}` donde
        * `registros` es una lista de `{linea_fisica, dato}`
        * `errores` es una lista de `{linea_fisica, mensaje}` (registros mal formados)
    * `{:error, :archivo_no_encontrado, ruta}` si el archivo no existe
    * `{:error, :archivo_ilegible, ruta}` si no se puede abrir

  El `dato` es:

    * `leer_terrenos/1` -> `%Terreno{}`
    * `leer_tareas/1`   -> `%Tarea{}`
    * `leer_edificio/1` -> lista de símbolos de la fila (`["X", "S", "."]`)
    * `leer_bateria/1`  -> texto crudo de la línea (el validador decide si es un entero positivo)

  El lector solo rechaza lo que no puede convertir (campos faltantes, enteros mal
  formados). Las reglas de negocio (duplicados, ciclos, bordes, etc.) las revisa
  el validador usando los números de línea que aquí se conservan.
  """

  @bom "﻿"

  @typedoc "Resultado de cualquier `leer_*`: registros `{linea, dato}` y errores `{linea, mensaje}`."
  @type resultado(dato) ::
          {:ok, [{pos_integer(), dato}], [{pos_integer(), String.t()}]}
          | {:error, :archivo_no_encontrado | :archivo_ilegible, Path.t()}

  @typedoc "Mapa del edificio: celdas `{fila, col} => simbolo`, dimensiones, inicio y meta."
  @type mapa :: %{
          celdas: %{{non_neg_integer(), non_neg_integer()} => String.t()},
          filas: non_neg_integer(),
          columnas: non_neg_integer(),
          inicio: {non_neg_integer(), non_neg_integer()} | nil,
          meta: {non_neg_integer(), non_neg_integer()} | nil
        }

  # ---------------------------------------------------------------------------
  # Flujo base
  # ---------------------------------------------------------------------------

  @doc """
  Stream perezoso de `{linea_fisica, texto}` sin líneas en blanco ni comentarios.
  El número de línea es el de la línea física original (empieza en 1).

  Es la base de todos los lectores: usa `File.stream!/1`, así que el archivo nunca
  se carga completo en memoria.
  """
  @spec lineas_utiles(Path.t()) :: Enumerable.t()
  def lineas_utiles(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {texto, numero} ->
      {numero, texto |> a_utf8() |> String.trim_leading(@bom) |> String.trim()}
    end)
    |> Stream.reject(fn {_numero, texto} -> texto == "" or String.starts_with?(texto, "#") end)
  end

  # Un archivo guardado en Latin-1 (común en Windows) se convierte para poder reportarlo
  defp a_utf8(texto) do
    if String.valid?(texto) do
      texto
    else
      :unicode.characters_to_binary(texto, :latin1)
    end
  end

  defp leer(ruta, parser) do
    if File.regular?(ruta) do
      {registros, errores} =
        ruta
        |> lineas_utiles()
        |> Stream.map(fn {numero, texto} -> parser.(numero, texto) end)
        |> Enum.reduce({[], []}, fn
          {:ok, registro}, {regs, errs} -> {[registro | regs], errs}
          {:error, error}, {regs, errs} -> {regs, [error | errs]}
        end)

      {:ok, Enum.reverse(registros), Enum.reverse(errores)}
    else
      {:error, :archivo_no_encontrado, ruta}
    end
  rescue
    _ in File.Error -> {:error, :archivo_ilegible, ruta}
  end

  # ---------------------------------------------------------------------------
  # Lectores públicos
  # ---------------------------------------------------------------------------

  @doc """
  Lee `terrenos.csv` (`simbolo,nombre,transitable,costo`).

  Devuelve `%Terreno{}` por registro. `transitable` es `si`/`no` en el CSV y
  `true`/`false` en el struct.

  ## Ejemplo

      {:ok, registros, errores} = Lector.leer_terrenos("terrenos.csv")
      # registros => [{2, %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0}}, ...]
  """
  @spec leer_terrenos(Path.t()) :: resultado(Terreno.t())
  def leer_terrenos(ruta), do: leer(ruta, &parsear_terreno/2)

  @doc """
  Lee `edificio.txt`: cada fila trae símbolos separados por espacios.

  Devuelve cada fila como `{linea, ["X", "S", "."]}`. No comprueba que la cuadrícula
  sea rectangular ni que los símbolos existan: eso es del validador.
  """
  @spec leer_edificio(Path.t()) :: resultado([String.t()])
  def leer_edificio(ruta), do: leer(ruta, &parsear_fila/2)

  @doc """
  Lee `bateria.txt` y devuelve el texto crudo de cada línea de datos.

  El validador decide si hay un único entero positivo; para convertirlo después
  de validar use `entero_bateria/1`.
  """
  @spec leer_bateria(Path.t()) :: resultado(String.t())
  def leer_bateria(ruta), do: leer(ruta, fn linea, texto -> {:ok, {linea, texto}} end)

  @doc """
  Lee `tareas.csv` (`id;duracion;plazo;dependencias`).

  Devuelve `%Tarea{}` por registro. Las dependencias `-` quedan como `[]` y
  `B|C` como `["B", "C"]`. Un registro con campos faltantes se reporta en la lista
  de errores con su línea física. Una duración o un plazo que no sea entero se deja
  como texto para que `ValidadorTareas` lo reporte.

  ## Ejemplo

      {:ok, registros, errores} = Lector.leer_tareas("tareas.csv")
      # registros => [{2, %Tarea{id: "A", duracion: 3, plazo: 4, dependencias: []}}, ...]
  """
  @spec leer_tareas(Path.t()) :: resultado(Tarea.t())
  def leer_tareas(ruta), do: leer(ruta, &parsear_tarea/2)

  # ---------------------------------------------------------------------------
  # Utilidades para el resto del programa
  # ---------------------------------------------------------------------------

  @doc """
  Índice `simbolo => %Terreno{}` (si un símbolo se repite, gana el primero).

  ## Ejemplos

      iex> terreno = %Terreno{simbolo: ".", nombre: "pasillo", transitable: true, costo: 1}
      iex> indice = Lector.indice_terrenos([{1, terreno}])
      iex> indice["."].costo
      1
  """
  @spec indice_terrenos([{pos_integer(), Terreno.t()}]) :: %{String.t() => Terreno.t()}
  def indice_terrenos(registros) do
    Enum.reduce(registros, %{}, fn {_linea, %Terreno{simbolo: simbolo} = terreno}, acumulado ->
      Map.put_new(acumulado, simbolo, terreno)
    end)
  end

  @doc """
  Construye el mapa del edificio a partir de las filas leídas. Debe llamarse
  solo cuando la validación del edificio no reportó errores.

  Devuelve `%{celdas: %{{fila, col} => simbolo}, filas: n, columnas: m, inicio: pos, meta: pos}`.
  Las coordenadas son `{fila, columna}` con origen en 0. El segundo argumento es
  opcional y se ignora (se acepta por compatibilidad con quien pase el índice de terrenos).

  ## Ejemplos

      iex> mapa = Lector.construir_mapa([{1, ["S", "."]}, {2, [".", "M"]}])
      iex> {mapa.filas, mapa.columnas, mapa.inicio, mapa.meta}
      {2, 2, {0, 0}, {1, 1}}
  """
  @spec construir_mapa([{pos_integer(), [String.t()]}]) :: mapa()
  @spec construir_mapa([{pos_integer(), [String.t()]}], term()) :: mapa()
  def construir_mapa(filas, _indice_terrenos \\ nil) do
    celdas =
      for {{_linea, simbolos}, fila} <- Enum.with_index(filas),
          {simbolo, columna} <- Enum.with_index(simbolos),
          into: %{},
          do: {{fila, columna}, simbolo}

    columnas =
      case filas do
        [] -> 0
        [{_linea, primera} | _] -> length(primera)
      end

    %{
      celdas: celdas,
      filas: length(filas),
      columnas: columnas,
      inicio: buscar_simbolo(celdas, "S"),
      meta: buscar_simbolo(celdas, "M")
    }
  end

  @doc """
  Convierte el registro de `leer_bateria/1` en `{:ok, entero}` o `:error`.

  ## Ejemplos

      iex> Lector.entero_bateria([{1, "10"}])
      {:ok, 10}

      iex> Lector.entero_bateria([{1, "diez"}])
      :error

      iex> Lector.entero_bateria([])
      :error
  """
  @spec entero_bateria([{pos_integer(), String.t()}]) :: {:ok, integer()} | :error
  def entero_bateria([{_linea, texto}]) do
    case Integer.parse(texto) do
      {valor, ""} -> {:ok, valor}
      _ -> :error
    end
  end

  def entero_bateria(_otro), do: :error

  defp buscar_simbolo(celdas, simbolo) do
    celdas
    |> Enum.filter(fn {_posicion, s} -> s == simbolo end)
    |> Enum.map(fn {posicion, _s} -> posicion end)
    |> Enum.sort()
    |> List.first()
  end

  # ---------------------------------------------------------------------------
  # Parsers de línea
  # ---------------------------------------------------------------------------

  defp parsear_fila(linea, texto), do: {:ok, {linea, String.split(texto)}}

  defp parsear_terreno(linea, texto) do
    case texto |> String.split(",") |> Enum.map(&String.trim/1) do
      [simbolo, nombre, transitable, costo] ->
        with {:ok, simbolo} <- validar_simbolo(simbolo),
             {:ok, transitable} <- parsear_transitable(transitable),
             {:ok, costo} <- parsear_entero(costo) do
          {:ok,
           {linea,
            %Terreno{simbolo: simbolo, nombre: nombre, transitable: transitable, costo: costo}}}
        else
          {:error, motivo} -> {:error, {linea, motivo}}
        end

      campos ->
        {:error,
         {linea,
          "se esperaban 4 campos (simbolo,nombre,transitable,costo) y hay #{length(campos)}"}}
    end
  end

  defp validar_simbolo(simbolo) do
    if String.length(simbolo) == 1 do
      {:ok, simbolo}
    else
      {:error, "el símbolo debe ser un único carácter, se recibió #{inspect(simbolo)}"}
    end
  end

  # Un valor que no se puede convertir se deja como texto: el registro sigue existiendo
  # y ValidadorEdificio lo reporta sin causar errores falsos en las casillas que lo usan.
  defp parsear_transitable(texto) do
    case String.downcase(texto) do
      "si" -> {:ok, true}
      "no" -> {:ok, false}
      _ -> {:ok, texto}
    end
  end

  defp parsear_tarea(linea, texto) do
    case texto |> String.split(";") |> Enum.map(&String.trim/1) do
      [id, duracion, plazo, dependencias] ->
        with {:ok, id} <- validar_id(id),
             {:ok, duracion} <- parsear_entero(duracion),
             {:ok, plazo} <- parsear_entero(plazo),
             {:ok, dependencias} <- parsear_dependencias(dependencias) do
          {:ok,
           {linea,
            %Tarea{id: id, duracion: duracion, plazo: plazo, dependencias: dependencias}}}
        else
          {:error, motivo} -> {:error, {linea, motivo}}
        end

      campos ->
        {:error,
         {linea,
          "se esperaban 4 campos (id;duracion;plazo;dependencias) y hay #{length(campos)}"}}
    end
  end

  defp validar_id(""), do: {:error, "el id de la tarea está vacío"}
  defp validar_id(id), do: {:ok, id}

  # Si no es entero se deja el texto, para que el validador lo reporte con su línea
  defp parsear_entero(texto) do
    case Integer.parse(texto) do
      {valor, ""} -> {:ok, valor}
      _ -> {:ok, texto}
    end
  end

  defp parsear_dependencias(""), do: {:error, "dependencias vacías (use - para ninguna)"}
  defp parsear_dependencias("-"), do: {:ok, []}

  defp parsear_dependencias(texto) do
    {:ok, texto |> String.split("|") |> Enum.map(&String.trim/1)}
  end
end
