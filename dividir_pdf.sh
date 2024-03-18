#! /bin/bash

## Verificaciones
################################################################
# Verificar si se proporciona un argumento
if [ $# -le 1 ]; then
    echo "Uso: $0 <ruta o nombre del archivo>.pdf <numero de carillas por cuadernillo>"
    exit 1
fi

# Verificar si el archivo proporcionado existe y es un archivo PDF
if [ ! -f "$1" ]; then
    echo "El archivo $1 no existe."
    exit 1
elif ! file -b "$1" | grep -q 'PDF'; then
    echo "El archivo $1 no es un archivo PDF válido."
    exit 1
fi

# Lista de dependencias y paquetes correspondientes
dependencies=("poppler-utils" "pdftk")
packages=("pdfinfo" "pdftk")

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

## Script
################################################################
# Calcular el número total de páginas del PDF
total_paginas=$(pdfinfo "$1" | grep "Pages" | awk '{print $2}')
cxc=$(($2*4))

# Calcular la cantidad de PDFs a generar
numero_pdfs=$((total_paginas / $cxc ))
resto=$((total_paginas % $cxc))

if [ $resto -gt 0 ]; then
    numero_pdfs=$((numero_pdfs + 1))
fi

# Generar una carpeta <nombre_pdf> para guardar los pdf
nombre_pdf=$(basename "$1")
nombre_dir="${nombre_pdf%.pdf}_pdfs_divididos"
i=0
while [ -d "$nombre_dir" ]; do
    i=$((i + 1))
    nombre_dir="${nombre_pdf%.pdf}_pdfs_divididos_$i"
done
mkdir "$nombre_dir"
echo "Carpeta $nombre_dir generada"

# Generar los PDFs en la carpeta
for ((i = 1; i <= $numero_pdfs; i++)); do
    inicio=$(($cxc * (i - 1) + 1))
    fin=$(($cxc * i))
    if [ $fin -gt $total_paginas ]; then
        fin=$total_paginas
    fi

    nombre_pdfs="${nombre_pdf%.pdf}_parte$i.pdf"

    pdftk "$1" cat $inicio-$fin output tmp.pdf

    mv tmp.pdf "$nombre_dir/$nombre_pdfs"

    echo "PDF generado: $nombre_pdfs"
done
echo "Podras encontrar los pdfs en la carpeta $nombre_dir"

# Eliminar tmp.pdf si existen

if [ -f "tmp.pdf" ]; then
    rm tmp.pdf
fi
