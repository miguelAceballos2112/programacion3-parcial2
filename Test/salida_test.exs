defmodule SalidaTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  @moduletag :tmp_dir

  defp plan_ejemplo do
    %Plan{
      orden: ["A", "B", "C", "D"],
      finalizaciones: [{"A", 0, 3}, {"B", 3, 5}, {"C", 5, 9}, {"D", 9, 10}],
      penalizacion: 4
    }
  end

  # --- recorridos_rescate.csv ------------------------------------------------

  test "recorridos_rescate.csv se escribe progresivamente con ids consecutivos", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "salida/recorridos_rescate.csv")
    dispositivo = Salida.abrir_recorridos(ruta)

    actualizar = fn id, _recorrido, ids -> [id | ids] end
    receptor = Salida.receptor_recorridos(dispositivo, actualizar)

    recorridos = [
      %Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}], energia: 5},
      %Recorrido{posiciones: [{1, 1}, {2, 1}], energia: 1}
    ]

    assert {2, [2, 1]} = Enum.reduce(recorridos, {0, []}, receptor)
    Salida.cerrar(dispositivo)

    assert File.read!(ruta) ==
             "id;movimientos;energia;posiciones\n" <>
               "1;2;5;(1,1)->(1,2)->(1,3)\n" <>
               "2;1;1;(1,1)->(2,1)\n"
  end

  test "recorridos_rescate.csv sin recorridos solo trae la cabecera", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "vacio.csv")
    dispositivo = Salida.abrir_recorridos(ruta)
    Salida.cerrar(dispositivo)
    assert File.read!(ruta) == "id;movimientos;energia;posiciones\n"
  end

  # --- planes.csv ------------------------------------------------------------

  test "planes.csv usa ; y flecha entre IDs", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "planes.csv")
    dispositivo = Salida.abrir_planes(ruta)
    receptor = Salida.receptor_planes(dispositivo, fn _id, _plan, estado -> estado end)

    segundo = %Plan{
      orden: ["A", "C", "B", "D"],
      finalizaciones: [{"A", 0, 3}, {"C", 3, 7}, {"B", 7, 9}, {"D", 9, 10}],
      penalizacion: 6
    }

    assert {2, :ok} = Enum.reduce([plan_ejemplo(), segundo], {0, :ok}, receptor)
    Salida.cerrar(dispositivo)

    assert File.read!(ruta) ==
             "id;orden;duracion_total;penalizacion\n" <>
               "1;A → B → C → D;10;4\n" <>
               "2;A → C → B → D;10;6\n"
  end

  test "Plan.duracion_total con plan vacío es 0" do
    assert Plan.duracion_total(%Plan{}) == 0
    assert Plan.duracion_total(plan_ejemplo()) == 10
  end

  # --- resúmenes -------------------------------------------------------------

  test "resumen_rescate con recorridos", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "resumen_rescate.txt")
    corto = {2, %Recorrido{posiciones: [{1, 1}, {2, 1}, {3, 1}], energia: 2}}

    datos = %{
      total: 3,
      bateria: 10,
      menos_movimientos: [corto],
      menor_energia: [corto]
    }

    pantalla = capture_io(fn -> Salida.resumen_rescate(ruta, datos) end)
    archivo = File.read!(ruta)

    assert archivo == pantalla
    assert archivo =~ "Total de recorridos válidos: 3"
    assert archivo =~ "Presupuesto de energía B: 10"
    assert archivo =~ "menos movimientos (2 movimientos): 1"
    assert archivo =~ "menor consumo (2 de energía): 1"
    assert archivo =~ "#2: (1,1)->(2,1)->(3,1)"
  end

  test "resumen_rescate sin recorrido válido lo indica", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "resumen_rescate.txt")
    :ok = Salida.resumen_rescate(ruta, %{total: 0, bateria: 1}, mostrar: false)
    assert File.read!(ruta) =~ "No existe recorrido válido"
  end

  test "resumen_tareas con planes", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "resumen_tareas.txt")

    datos = %{
      total: 2,
      vacio: false,
      penalizacion_minima: 4,
      mejores: [{1, plan_ejemplo()}]
    }

    :ok = Salida.resumen_tareas(ruta, datos, mostrar: false)
    archivo = File.read!(ruta)
    assert archivo =~ "Total de planes válidos: 2"
    assert archivo =~ "Tiempo total del proyecto: 10"
    assert archivo =~ "Penalización mínima: 4"
    assert archivo =~ "Planes que alcanzan la penalización mínima: 1"
    assert archivo =~ "#1: A → B → C → D"
  end

  test "resumen_tareas con proyecto vacío y sin planes", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "resumen_tareas.txt")
    :ok = Salida.resumen_tareas(ruta, %{total: 0, vacio: true}, mostrar: false)
    assert File.read!(ruta) =~ "Proyecto vacío"

    :ok = Salida.resumen_tareas(ruta, %{total: 0, vacio: false}, mostrar: false)
    assert File.read!(ruta) =~ "No existe ningún plan válido"
  end

  # --- expansion_energia.txt -------------------------------------------------

  test "expansion_energia.txt ordena posiciones por fila y columna", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "expansion_energia.txt")
    pasos = [%{{1, 1} => 0}, %{{1, 2} => 1, {1, 1} => 0, {0, 5} => 9}]
    :ok = Salida.escribir_expansion(ruta, pasos, 1)

    assert File.read!(ruta) ==
             "Paso 0:\n  (1,1) = 0\n" <>
               "Paso 1:\n  (0,5) = 9\n  (1,1) = 0\n  (1,2) = 1\n" <>
               "Índice de estabilización: 1\n"
  end

  # --- validación y avisos ---------------------------------------------------

  test "escribir_validacion lista todos los errores con su ubicación", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "validacion_edificio.txt")

    errores = [
      {3, "costo no es un entero"},
      {{0, 2}, "el borde debe ser X"},
      {"general", "texto libre"}
    ]

    :ok = Salida.escribir_validacion(ruta, "Validación del edificio", errores)
    archivo = File.read!(ruta)
    assert archivo =~ "Errores encontrados: 3"
    assert archivo =~ "- línea 3: costo no es un entero"
    assert archivo =~ "- casilla (0,2): el borde debe ser X"
    assert archivo =~ "- general: texto libre"
  end

  test "escribir_validacion sin errores", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "validacion_tareas.txt")
    :ok = Salida.escribir_validacion(ruta, "Validación de tareas", [])
    assert File.read!(ruta) =~ "Sin errores."
  end

  test "avisar_error_lectura muestra un aviso claro" do
    salida =
      capture_io(fn ->
        assert :ok = Salida.avisar_error_lectura({:error, :archivo_no_encontrado, "datos/edificio.txt"})
      end)

    assert salida =~ "no se encontró el archivo requerido: datos/edificio.txt"
  end

  test "escribir sobre un archivo existente lo reemplaza", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "resumen.txt")
    File.write!(ruta, "contenido anterior muy largo que no debe quedar")
    :ok = Salida.escribir_validacion(ruta, "T", [])
    refute File.read!(ruta) =~ "anterior"
  end

  # --- formatos --------------------------------------------------------------

  test "Recorrido.movimientos con recorrido vacío es 0" do
    assert Recorrido.movimientos(%Recorrido{}) == 0
  end
end
