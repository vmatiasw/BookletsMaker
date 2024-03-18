#! /bin/bash

## Verificaciones
################################################################
if (($# <= 2)); then # Verifica si se proporciona un argumento
    echo "Faltan parametros obligatorios
Sintaxis: $0 <ruta o nombre del archivo>.pdf -is: <1 para simple fas y 0 para doble fas>"
    exit 1
fi

if [ ! -f "$1" ]; then # Verifica si no existe el archivo $1 (! -f "$1" )
    echo "El archivo $1 no existe."
    exit 1
else
    if ! file -b "$1" | grep -q 'PDF document'; then # Verifica si es un PDF
        echo "El archivo $1 no es un archivo PDF válido."
        exit 1
    fi
fi

# Lista de dependencias y paquetes correspondientes
dependencies=("pdftk")
packages=("pdftk")

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

## Flags
################################################################

impresora_simple=1
for ((i = 2; i <= $#; i++)); do
    case "${!i}" in
    -is:)
        i=$(($i + 1))
        regex='^[0,1]$' # Expresión regular que coincide con solo 0 o 1
        if ! [[ ${!i} =~ $regex ]]; then
            echo "Luego de '-is: ' va 1 para simple fas y 0 para doble fas"
            exit 1
        fi
        impresora_simple=${!i}
        ;;
    *)
        echo "Valor no válido en el argumento $i: ${!i}"
        exit 1
        ;;
    esac
done

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

function imprimir() { #arg 1: nombre de pdf existente para imprimir.
    nombre_de_la_impresora=$(lpstat -d | awk '{print $5}')
    if (($impresora_simple)); then
        res=$(lp $1 2>&1)
        check_error1 "XX Error: Fallo con la impresora en el comando $res"
    else
        # Imprimimos doble cara con eje en la parte larga de la hoja
        res=$(lp -o sides=two-sided-long-edge $1 2>&1)
        check_error1 "XX Error: Fallo con la impresora en el comando $res"
    fi
    echo "Se ha mandado a imprimir el archivo $1 a la impresora: $nombre_de_la_impresora."
    echo "Por favor espere..."
    # Esperamos a que la impresora termine de imprimir
    while (($(lpstat -o $nombre_de_la_impresora | wc -c))); do
        sleep 1
    done
    echo "Impresión del archivo $1 finalizada."
}

## Script
################################################################

# lpoptions -p NOMBRE_DE_LA_IMPRESORA -l   para ver si la impresora imprime doble cara auto

echo "// Imprimiendo ..."

if (($impresora_simple)); then
    ## Imprimimos una cara y despues la otra
    # Generar una carpeta tmp para los archivos temporales
    nombre_dir_tmp="tmp"
    i=0
    while [ -d "$nombre_dir_tmp" ]; do
        i=$((i + 1))
        nombre_dir_tmp="tmp_$i"
    done
    mkdir "$nombre_dir_tmp"
    # Sacamos info
    pdf_input=$(basename "$1")
    # Separamos un archivo para cada cara
    tmp_pdf_cara1=$nombre_dir_tmp/${pdf_input%.pdf}_encuadernado_cara1.pdf
    tmp_pdf_cara2=$nombre_dir_tmp/${pdf_input%.pdf}_encuadernado_cara2.pdf
    pdftk $1 cat odd output $tmp_pdf_cara1
    pdftk $1 cat even output $tmp_pdf_cara2
    # Imprimimos
    imprimir $tmp_pdf_cara1
    echo "Agarrar lo impreso, darle una vuelta de 180 grados con eje en la parte mas larga, ponerlo para imprimir y presionar 'enter' en la terminal"
    read
    imprimir $tmp_pdf_cara2
    # Eliminamos los pdfs
    rm $tmp_pdf_cara1 $tmp_pdf_cara2
    # Borramos la carpeta temporal
    rm -rf $nombre_dir_tmp
else
    ## Imprimimos ambas caras a la vez.
    imprimir $1
fi
echo "Impresion finalizada!"
