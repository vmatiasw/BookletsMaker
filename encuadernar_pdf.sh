#! /bin/bash

## Verificaciones
################################################################
# Verificamos si se proporciona un argumento
if [ $# -eq 0 ]; then
    echo "Uso: $0 <ruta o nombre del archivo>.pdf"
    exit 1
fi

# Verificamos si el archivo proporcionado existe y es un archivo PDF
if [ ! -f "$1" ]; then
    echo "El archivo $1 no existe."
    exit 1
fi

# Lista de dependencias y paquetes correspondientes
dependencies=("poppler-utils" "imagemagick" "pdftk" "texlive-extra-utils")
packages=("pdfinfo" "convert" "pdftk" "pdfjam")

# Verificar si todas las dependencias están instaladas
missing_dependencies=()
for ((i = 0; i < ${#dependencies[@]}; i++)); do
    if ! command -v ${packages[$i]} &>/dev/null; then
        missing_dependencies+=(${dependencies[$i]})
    fi
done

# Verificar si faltan dependencias
if [ ${#missing_dependencies[@]} -gt 0 ]; then
    echo "Faltan las siguientes dependencias:"
    for dependency in "${missing_dependencies[@]}"; do
        echo "- $dependency"
    done
    echo "Puedes instalarlas con los siguientes comandos:"
    for package in "${dependencies[@]}"; do
        echo "sudo apt-get install $package"
    done
    exit 1
fi

## Funciones
################################################################

## Script
################################################################
# Generar una carpeta tmp para los archivos temporales
nombre_dir_tmp="tmp"
i=0
while [ -d "$nombre_dir_tmp" ]; do
    i=$((i + 1))
    nombre_dir_tmp="tmp_$i"
done
mkdir "$nombre_dir_tmp"

# Creamos algunas variables de archivos temporales
tmp_archivo_inicial=$nombre_dir_tmp/tmp_archivo_inicial.pdf
tmp_merge_=$nombre_dir_tmp/tmp_merge_
tmp_rotated_=$nombre_dir_tmp/tmp_rotated_

# Obtener numero de hojas y tamaño pdf
total_paginas=$(pdfinfo "$1" | grep "Pages" | awk '{print $2}')
page_size=$(pdfinfo "$1" | grep "Page size" | awk '{print $3"x"$5}')

# Creamos tmp_archivo_inicial
cp $1 $tmp_archivo_inicial

# Juntamos las paginas y vamos agregando sus nombres al array merges[]
merges=()
for ((i = 1; i <= $total_paginas / 2; i++)); do
    # Definimos que va a izquierda y que a derecha segun la cara
    if ((($i % 2) == 0)); then # Cara 2 (n pares)
        izq=$i
        der=$((total_paginas - i + 1))
    else # Cara 1 (n impares)
        izq=$((total_paginas - i + 1))
        der=$i
    fi
    # Juntamos en un archivo pdf
    pdfjam --outfile $tmp_merge_$i.pdf --nup 2x1 --landscape $tmp_archivo_inicial $izq,$der &>/dev/null
    # Si es Cara 1, osea impar lo rotamos 180 grados
    if ((!(($i % 2) == 0))); then
        pdftk $tmp_merge_$i.pdf cat 1-endsouth output $tmp_rotated_$i.pdf
        mv $tmp_rotated_$i.pdf $tmp_merge_$i.pdf
    fi
    # Agregamos el nombre del archivo al array
    merges+=("$tmp_merge_$i.pdf")
done

# Creamos el archivo final
nombre_input=$(basename "$1")
nombre_pdf="${nombre_input%.pdf}_encuadernado.pdf"
i=0
while [ -f "$nombre_pdf" ]; do
    i=$((i + 1))
    nombre_pdf="${nombre_input%.pdf}_encuadernado_$i.pdf"
done
touch $nombre_pdf

# Unimos todos los archivos generados
pdftk ${merges[*]} cat output $nombre_pdf

# Borramos los archivos temporales
rm ${merges[*]} $tmp_archivo_inicial
# Borramos la carpeta temporal
rm -rf $nombre_dir_tmp

echo "PDF generado: $nombre_pdf"
