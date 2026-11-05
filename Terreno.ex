defmodule Terreno do
  defstruct simbolo: "", nombre: "", transitable: false, costo: 0

  def crear(simbolo, nombre, transitable, costo) do
    %Terreno{
      simbolo: simbolo,
      nombre: nombre,
      transitable: transitable,
      costo: costo
    }
  end
end
