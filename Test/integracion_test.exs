defmodule IntegracionTest do
  @moduledoc """
  Pruebas de punta a punta del orquestador con los archivos de fixtures/.
  Cada caso escribe sus salidas en su propia carpeta de fixtures/.
  """
  use ExUnit.Case

  import ExUnit.CaptureIO

  @salidas_rescate [
    "expansion_energia.txt",
    "recorridos_rescate.csv",
    "resumen_rescate.txt",
    "ruta_optima.svg"
  ]

  @salidas_tareas ["planes.csv", "resumen_tareas.txt", "mejor_plan.svg"]

  # --- Problema 1 ------------------------------------------------------------

  test "rescate valido" do
    correr_rescate("valido", {:ok, :con_recorridos}, @salidas_rescate)
  end

  test "rescate limite_minimo" do
    correr_rescate("limite_minimo", {:ok, :con_recorridos}, @salidas_rescate)
  end

  test "rescate limite_sin_recorrido" do
    correr_rescate("limite_sin_recorrido", {:ok, :sin_recorrido}, @salidas_rescate)
  end

  test "rescate invalido no genera salidas" do
    correr_rescate("invalido", {:error, :validacion}, [])
  end

  test "rescate falta_archivo no genera salidas" do
    correr_rescate("falta_archivo", {:error, :faltan_archivos}, [])
  end

  # --- Problema 2 ------------------------------------------------------------

  test "tareas valido produce las dos filas del enunciado" do
    correr_tareas("valido", {:ok, :con_planes}, @salidas_tareas)

    ruta = "fixtures/tareas/valido/planes.csv"
    assert contar_lineas(ruta, "1;A → B → C → D;10;4") == 1
    assert contar_lineas(ruta, "2;A → C → B → D;10;6") == 1
  end

  test "tareas limite_una" do
    correr_tareas("limite_una", {:ok, :con_planes}, @salidas_tareas)
  end

  test "tareas vacio" do
    correr_tareas("vacio", {:ok, :proyecto_vacio}, @salidas_tareas)
  end

  test "tareas invalido no genera salidas" do
    correr_tareas("invalido", {:error, :validacion}, [])
  end

  # Tres tareas donde cada una depende de las otras dos forman exactamente 5 ciclos
  test "tareas ciclos: 5 ciclos sin rotaciones repetidas" do
    correr_tareas("ciclos", {:error, :validacion}, [])

    assert contar_lineas("fixtures/tareas/ciclos/validacion_tareas.txt", "Ciclo") == 5
  end

  # La tarea con duración mal formada sigue existiendo: quien depende de ella no da un
  # error falso de dependencia desconocida
  test "tareas no_entero: un solo error, sin dependencia falsa" do
    correr_tareas("no_entero", {:error, :validacion}, [])

    ruta = "fixtures/tareas/no_entero/validacion_tareas.txt"
    assert contar_lineas(ruta, "Errores encontrados: 1") == 1
    assert contar_lineas(ruta, "que no existe") == 0
  end

  test "tareas con la carpeta inexistente avisa que falta el archivo" do
    correr_tareas("no_existe", {:error, :faltan_archivos}, [])
  end

  # --- Funciones auxiliares --------------------------------------------------

  defp correr_rescate(nombre, esperado, deben_generarse) do
    carpeta = "fixtures/rescate/#{nombre}"
    vaciar(carpeta, deben_generarse)

    assert sin_mensajes(fn -> Orquestador.rescate(carpeta) end) == esperado
    revisar_salidas(carpeta, @salidas_rescate, deben_generarse)
  end

  defp correr_tareas(nombre, esperado, deben_generarse) do
    carpeta = "fixtures/tareas/#{nombre}"
    vaciar(carpeta, deben_generarse)

    assert sin_mensajes(fn -> Orquestador.tareas(carpeta) end) == esperado
    revisar_salidas(carpeta, @salidas_tareas, deben_generarse)
  end

  # Ejecuta sin mostrar lo que el programa escribe en pantalla ni los avisos de error
  defp sin_mensajes(funcion) do
    {{resultado, _pantalla}, _errores} = with_io(:stderr, fn -> with_io(funcion) end)
    resultado
  end

  # Deja vacías las salidas que el caso debe generar, para que una salida
  # de una ejecución anterior no haga pasar la prueba.
  defp vaciar(carpeta, archivos) do
    Enum.each(archivos, fn archivo -> File.write!("#{carpeta}/#{archivo}", "") end)
  end

  # Cada archivo debe haberse generado solo si el caso debía hacerlo
  defp revisar_salidas(carpeta, salidas, deben_generarse) do
    Enum.each(salidas, fn archivo ->
      assert {archivo, generado?("#{carpeta}/#{archivo}")} == {archivo, archivo in deben_generarse}
    end)
  end

  # Un archivo cuenta como generado solo si existe y tiene contenido
  defp generado?(ruta) do
    case File.read(ruta) do
      {:ok, ""} -> false
      {:ok, _contenido} -> true
      {:error, _razon} -> false
    end
  end

  defp contar_lineas(ruta, texto) do
    ruta
    |> File.stream!()
    |> Stream.filter(fn linea -> String.contains?(linea, texto) end)
    |> Enum.count()
  end
end
