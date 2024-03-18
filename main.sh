#! /bin/bash

function getHelp() {
    echo "
    Sintaxis: $0 <ruta o nombre del archivo>.pdf -cxc: <numero (entero mayor a 4) de hojas por cuadernillo> <flags>
    PD: cada hoja tiene 4 carillas
    flags: 
        -help: Este mensaje de ayuda :) daa
        -impresora_simple: Imprime primero un lado, el usuario debe rotar con eje en el largo las hojas impresas, colocarlas para imprimir y presionar enter en la terminal.
        -imprimir <0 o 1>: Imprime el pdf en simple fas (1) o doble fas (0)
        "
}

## Verificaciones
################################################################
if [ $# -eq 0 ]; then # Verifica si se proporciona un argumento
    echo "No se detecto ningun archivo PDF como parametro 
Sintaxis: $0 ./<ruta o nombre del archivo>.pdf -cxc: <numero de hojas (cada hoja tiene 4 carillas) por cuadernillo> <flags>
Flags: 
    '-imprimir: <tipo>': imprime el pdf formado en la impresora tipo 0 (doble fas) o 1 (simple fas).
    '-help': este mensaje de ayuda."
    exit 1
fi

if [ ! -f "$1" ]; then # Verifica si no existe el archivo $1 (! -f "$1" )
    if (($1 == help)); then
        getHelp
        exit 0
    fi
    echo "El archivo $1 no existe."
    exit 1
else
    if ! file -b "$1" | grep -q 'PDF document'; then # Verifica si es un PDF
        echo "El archivo $1 no es un archivo PDF válido."
        exit 1
    fi
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
if [ ${#missing_dependencies[@]} -eq 0 ]; then
    echo "Todas las dependencias están instaladas."
else
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

## Flags
################################################################

impresora_simple=1
imprimir=0
cxc=0
for ((i = 2; i <= $#; i++)); do
    case "${!i}" in
    -imprimir:)
        i=$(($i + 1))
        regex='^[0,1]$' # Expresión regular que coincide con solo 0 o 1
        if ! [[ ${!i} =~ $regex ]]; then
            echo "Luego de '-imprimir: ' va 1 para simple fas y 0 para doble fas"
            exit 1
        fi
        impresora_simple=${!i}
        imprimir=1
        ;;
    -cxc:)
        i=$(($i + 1))
        cxc=${!i}
        regex='^[0-9]+$' # Expresión regular que coincide con solo números
        if ! [[ $cxc =~ $regex ]]; then
            echo "Luego de '-cxc: ' va el numero de hojas (cada hoja tiene 4 carillas) por cuadernillo."
            exit 1
        fi
        ;;
    -help)
        getHelp
        exit 0
        ;;
    *)
        echo "Valor no válido en el argumento $i: ${!i}"
        exit 1
        ;;
    esac
done

# verificamos cxc
if [ $cxc -le 4 ]; then
    echo "El parametro -cxc: <numero (entero mayor a 4) de hojas por cuadernillo> es obligatorio.
    PD: cada hoja tiene 4 carillas."
    exit 1
fi

## Funciones
################################################################

function check_error1() {
    estado_error=$? #(del anterior comando)
    if (($estado_error)); then
        echo $1
        if [ -d $nombre_dir_tmp ]; then
            rm -rf $nombre_dir_tmp
        fi
        exit 1
    fi
}

function agregar_paginas_en_blanco() { #args: $1:pdf  #return:$tmp_archivo_inicial

    tmp_blank=$nombre_dir_tmp/tmp_blank.pdf

    # Obtener numero de hojas y tamaño pdf
    total_paginas=$(pdfinfo "$1" | grep "Pages" | awk '{print $2}')
    page_size=$(pdfinfo "$1" | grep "Page size" | awk '{print $3"x"$5}')

    # Creamos la pagina en blanco tmp_blank.pdf
    convert -size $page_size xc:white $tmp_blank

    # Concatenamos en tmp_archivo_inicial.pdf y aumentamos total_paginas
    pdftk $tmp_blank $tmp_blank $1 $tmp_blank $tmp_blank cat output $tmp_archivo_inicial
    total_paginas=$((total_paginas + 4))

    # Si el numero de paginas es impar agregar al final una en blanco...
    resto=$((total_paginas % 2))
    if (($resto > 0)); then
        # Concatenamos $1 ++ tmp_blank.pdf en tmp_archivo_inicial.pdf y aumentamos total_paginas
        tmp_aux=$nombre_dir_tmp/tmp_aux.pdf
        pdftk $tmp_archivo_inicial $tmp_blank cat output $tmp_aux
        mv $tmp_aux $tmp_archivo_inicial
        total_paginas=$((total_paginas + 1))
    fi

    # Borramos el archivo temporal tmp_blank.pdf
    rm $tmp_blank
}

function encuadernar_cuadernillos() {
    # Generar una carpeta <pdf_input>_encuadernados para guardar los pdf encuadernados
    dir_pdfs_encuadernados="${pdf_input%.pdf}_pdfs_encuadernados"
    i=0
    while [ -d "$dir_pdfs_encuadernados" ]; do
        i=$((i + 1))
        dir_pdfs_encuadernados="${pdf_input%.pdf}_pdfs_encuadernados_$i"
    done
    mkdir "$dir_pdfs_encuadernados"
    echo "Carpeta $dir_pdfs_encuadernados generada"

    # Encuadernamos los pdfs
    dir_pdfs_divididos="${pdf_input%.pdf}_pdfs_divididos"
    numero_pdfs=$(ls -l $dir_pdfs_divididos | grep "^-" | wc -l)
    for ((i = 1; i <= $numero_pdfs; i++)); do
        pdf_dividido=${pdf_input%.pdf}_parte$i.pdf
        ./encuadernar_pdf.sh ./$dir_pdfs_divididos/$pdf_dividido
        check_error1
        pdf_dividido_encuadernado=${pdf_input%.pdf}_parte$i\_encuadernado.pdf
        mv $pdf_dividido_encuadernado $dir_pdfs_encuadernados/
        # Agregamos el nombre del archivo al array
        pdfs_encuadernados+=("$dir_pdfs_encuadernados/$pdf_dividido_encuadernado")
    done
    echo "Podras encontrar los pdfs en la carpeta $dir_pdfs_encuadernados"
}

## Script
################################################################

# lpoptions -p NOMBRE_DE_LA_IMPRESORA -l   para ver si la impresora imprime doble cara auto

# Creamos directorio tmp para los archivos temporales
nombre_dir_tmp="tmp"
i=0
while [ -d "$nombre_dir_tmp" ]; do
    i=$((i + 1))
    nombre_dir_tmp="tmp_$i"
done
mkdir "$nombre_dir_tmp"

# Sacamos info
pdf_input=$(basename "$1")

# Creamos algunas variables de archivos temporales
tmp_archivo_inicial=$nombre_dir_tmp/$pdf_input

# Agregamos paginas en blaco
echo "// Agregando paginas en blanco ..."
agregar_paginas_en_blanco $1 # (Return: $tmp_archivo_inicial)
n_carillas_infofinal=$(pdfinfo "$tmp_archivo_inicial" | grep "Pages" | awk '{print $2}')

# chequeo por el minimo de hojas en el ultimo cuadernillo
min_hojas=3
n_cxc=$(($cxc * 4))
n_resto=$((n_carillas % $n_cxc))

if (($n_resto <= ($min_hojas * 4) && $n_resto != 0)); then
    echo "El ultimo cuadernillo ocupara menos de $min_hojas hojas. Desea seguir?"
    read -n 1 -p "(S/N) " res
    if [[ $res =~ ^[S,s]$ ]]; then
        echo "Continuando..."
    else
        rm $tmp_archivo_inicial
        rm -rf $nombre_dir_tmp
        echo "Saliendo..."
        exit 0
    fi

fi

# Dividimos el pdf en cuadernillos de $cxc hojas en una nueva carpeta
echo "// Dividiendo pdf en cuadernillos de $cxc hojas (cada hoja tiene 4 carillas) ..."
./dividir_pdf.sh $tmp_archivo_inicial $cxc # (Return: $dir_pdfs_divididos)
check_error1

# Eliminamos tmp_archivo_inicial y la carpeta temporal
rm $tmp_archivo_inicial
rm -rf $nombre_dir_tmp

# Encuadernamos los cuadernillos en dir_pdfs_encuadernados
echo "// Encuadernando cuadernillos ..."
encuadernar_cuadernillos # (Return: dir_pdfs_encuadernados, pdfs_encuadernados[])

# Sacamos algunos datos
ultimo_cuadernillo="${pdfs_encuadernados[@]: -1}"
echo $ultimo_cuadernillo
hojas_ultimoCuadernillo_infofinal=$(pdfinfo "$ultimo_cuadernillo" | grep "Pages" | awk '{print $2}')

# Juntamos todos los pdf en el pdf_encuadernado
echo "// Juntando todos los cuadernillos en un pdf ..."
pdf_final_encuadernado=${pdf_input%.pdf}_encuadernado.pdf
pdftk ${pdfs_encuadernados[*]} cat output $pdf_final_encuadernado
echo "PDF encuadernado: $pdf_final_encuadernado"

#sacamos algunos datos
n_hojas_infofinal=$(pdfinfo "$pdf_final_encuadernado" | grep "Pages" | awk '{print $2}')
n_cuadernillos_infofinal=$(ls -1 $dir_pdfs_divididos | wc -l)

# Eliminamos la carpetas
rm -rf $dir_pdfs_divididos $dir_pdfs_encuadernados
echo "Se han eliminado las carpetas: $dir_pdfs_divididos $dir_pdfs_encuadernados"

# Mandamos a imprimir si $imprimir=1
if (($imprimir)); then
    ./imprimir_pdf.sh $pdf_final_encuadernado -is: $impresora_simple
fi

# Informacion del cuaderno
page_size_infofinal=$(pdfinfo "$pdf_final_encuadernado" | grep "Page size:" | awk '{print $3" x "$5"  "$6"  "$7}')
file_size_infofinal=$(pdfinfo "$pdf_final_encuadernado" | grep "File size:" | awk '{print $3" "$4}')
echo "// Informacion general del cuaderno:"
echo " - Peso: $file_size_infofinal"
echo " - Proporciones: $page_size_infofinal"
echo " - Numero de cuadernillos: $n_cuadernillos_infofinal"
echo " - Numero de hojas: $n_hojas_infofinal"
echo " - Numero de carillas: $n_carillas_infofinal"
echo "// Informacion de los cuadernillos:"
hxc_infofinal=$(($n_hojas_infofinal / $n_cuadernillos_infofinal))
echo " - Hojas por cuadernillo: $hxc_infofinal"
echo " - Hojas en el ultimo cuadernillo: $hojas_ultimoCuadernillo_infofinal"

echo "Programa finalizado"
