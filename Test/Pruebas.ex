defmodule Pruebas do
  # Utilidades que comparten los archivos de pruebas.
  # Cada prueba es una tupla {nombre, obtenido, esperado}.

  def ejecutar(casos) do
    fallos = probar(casos)

    "\n#{length(casos)} pruebas, #{fallos} fallos"
    |> Util2.mostrar(:mensaje)
  end

  # Caso base: no quedan pruebas
  defp probar([]), do: 0

  # Caso recursivo: lo obtenido es igual a lo esperado
  defp probar([{nombre, obtenido, esperado} | tail]) when obtenido == esperado do
    Util2.mostrar("OK    #{nombre}", :mensaje)
    probar(tail)
  end

  # Caso recursivo: lo obtenido es diferente
  defp probar([{nombre, obtenido, esperado} | tail]) do
    Util2.mostrar("FALLO #{nombre}", :mensaje)
    IO.inspect(esperado, label: "  esperado")
    IO.inspect(obtenido, label: "  obtenido")

    1 + probar(tail)
  end

  # El texto contiene la parte si al partirlo por ella quedan dos pedazos o más
  def contiene_texto?(texto, parte), do: length(String.split(texto, parte)) > 1

  def ocurrencias(texto, parte), do: length(String.split(texto, parte)) - 1

  # Ruta de un archivo temporal de las pruebas. La carpeta no se sube a GitHub.
  # Salida.abrir crea la carpeta si no existe.
  def temporal(nombre) do
    ruta = "salida_pruebas/#{nombre}"

    ruta
    |> Salida.abrir()
    |> Salida.cerrar()

    ruta
  end
end
