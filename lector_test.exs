defmodule LectorTest do
  use ExUnit.Case, async: true

  @fixtures Path.expand("fixtures", __DIR__)

  defp fixture(nombre), do: Path.join(@fixtures, nombre)

  @moduletag :tmp_dir

  # --- casos válidos ---------------------------------------------------------

  test "lineas_utiles es perezoso, omite comentarios y conserva la línea física" do
    assert [{2, "X,pared,no,0"}] =
             fixture("terrenos.csv") |> Lector.lineas_utiles() |> Enum.take(1)
  end

  test "leer_terrenos devuelve structs con su línea" do
    assert {:ok, registros, []} = Lector.leer_terrenos(fixture("terrenos.csv"))
    assert length(registros) == 5

    assert {2, %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0}} =
             hd(registros)

    assert {4, %Terreno{simbolo: "L", nombre: "lodo", transitable: true, costo: 3}} =
             Enum.at(registros, 2)
  end

  test "leer_edificio devuelve las filas como listas de símbolos" do
    assert {:ok, filas, []} = Lector.leer_edificio(fixture("edificio.txt"))
    assert length(filas) == 5
    assert {1, ["X", "X", "X", "X", "X", "X"]} = hd(filas)
    assert {2, ["X", "S", ".", "L", "M", "X"]} = Enum.at(filas, 1)
  end

  test "leer_bateria y entero_bateria" do
    assert {:ok, [{1, "10"}] = registros, []} = Lector.leer_bateria(fixture("bateria.txt"))
    assert {:ok, 10} = Lector.entero_bateria(registros)
  end

  test "leer_tareas convierte dependencias" do
    assert {:ok, registros, []} = Lector.leer_tareas(fixture("tareas.csv"))
    assert Enum.map(registros, fn {_l, t} -> t.id end) == ["A", "B", "C", "D"]
    assert {2, %Tarea{id: "A", duracion: 3, plazo: 4, dependencias: []}} = hd(registros)
    assert {5, %Tarea{id: "D", dependencias: ["B", "C"]}} = List.last(registros)
  end

  test "construir_mapa e indice_terrenos" do
    {:ok, filas, []} = Lector.leer_edificio(fixture("edificio.txt"))
    {:ok, terrenos, []} = Lector.leer_terrenos(fixture("terrenos.csv"))

    mapa = Lector.construir_mapa(filas)
    assert mapa.filas == 5
    assert mapa.columnas == 6
    assert mapa.inicio == {1, 1}
    assert mapa.meta == {1, 4}
    assert mapa.celdas[{1, 3}] == "L"

    indice = Lector.indice_terrenos(terrenos)
    assert %Terreno{costo: 3} = indice["L"]
  end

  # --- casos inválidos -------------------------------------------------------

  test "archivo inexistente devuelve error en vez de excepción" do
    ruta = fixture("no_existe.csv")
    assert {:error, :archivo_no_encontrado, ^ruta} = Lector.leer_tareas(ruta)
    assert {:error, :archivo_no_encontrado, _} = Lector.leer_terrenos(ruta)
    assert {:error, :archivo_no_encontrado, _} = Lector.leer_edificio(ruta)
    assert {:error, :archivo_no_encontrado, _} = Lector.leer_bateria(ruta)
  end

  test "tareas mal formadas se reportan con su línea y no detienen la lectura" do
    assert {:ok, registros, errores} = Lector.leer_tareas(fixture("tareas_invalidas.csv"))
    assert Enum.map(registros, fn {_l, t} -> t.id end) == ["A", "D"]
    assert Enum.map(errores, fn {linea, _} -> linea end) == [3, 4, 5]
  end

  test "terrenos mal formados se reportan con su línea", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "terrenos_malos.csv")

    File.write!(ruta, """
    .,pasillo,si,1
    LL,lodo,si,3
    L,lodo,tal vez,3
    P,pared,no,abc
    Q,pared,no,-2
    R,roca,no
    """)

    assert {:ok, [{1, %Terreno{simbolo: "."}}], errores} = Lector.leer_terrenos(ruta)
    assert Enum.map(errores, fn {linea, _} -> linea end) == [2, 3, 4, 5, 6]
  end

  test "entero_bateria rechaza texto no entero y varias líneas" do
    assert :error = Lector.entero_bateria([{1, "diez"}])
    assert :error = Lector.entero_bateria([{1, "10"}, {2, "20"}])
    assert :error = Lector.entero_bateria([])
  end

  # --- casos límite ----------------------------------------------------------

  test "archivo solo con comentarios y líneas en blanco", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "vacio.csv")
    File.write!(ruta, "# solo comentario\n\n   \n  # otro comentario\n")
    assert {:ok, [], []} = Lector.leer_tareas(ruta)
    assert {:ok, [], []} = Lector.leer_edificio(ruta)
  end

  test "archivo completamente vacío", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "cero.csv")
    File.write!(ruta, "")
    assert {:ok, [], []} = Lector.leer_terrenos(ruta)
  end

  test "la numeración de línea cuenta comentarios y vacías", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "numeracion.csv")
    File.write!(ruta, "# c\n\nA;1;1;-\n   # otro\nB;1;1;A")
    assert {:ok, [{3, %Tarea{id: "A"}}, {5, %Tarea{id: "B", dependencias: ["A"]}}], []} =
             Lector.leer_tareas(ruta)
  end

  test "construir_mapa con lista vacía" do
    mapa = Lector.construir_mapa([])
    assert mapa.filas == 0
    assert mapa.columnas == 0
    assert mapa.inicio == nil
    assert mapa.meta == nil
  end

  test "ignora BOM al inicio del archivo", %{tmp_dir: tmp} do
    ruta = Path.join(tmp, "bom.txt")
    File.write!(ruta, "﻿10\n")
    assert {:ok, [{1, "10"}], []} = Lector.leer_bateria(ruta)
  end
end
