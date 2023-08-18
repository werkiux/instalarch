#!/bin/bash

#Limpiar pantalla.
clear

echo ""
echo "         #####################################################"
echo "         #                     BIENVENIDO!                   #"
echo "         #####################################################"
echo ""
printf "\n"

iwctl
echo "Interfaces inalambricas disponibles:"
station list
read -p "Escriba el nombre de su interfaz inalambrica:" interfaz
station $interfaz get-networks
read -p "Introduzca el nombre de su señal inalambrica(WiFi): " wifi
station $interfaz connect $wifi
ping -c 3 archlinux.org
sleep 3
clear

# Creando el sistema de archivos.
echo "Por favor introduzca la ruta de la particion EFI: (Ejemplo: /dev/sda1 o /dev/nvme0n1p1)"
read EFI
echo "Por favor introduzca la ruta de la particion Root(/): (Ejemplo: /dev/sda3 o /dev/nvme0n1p2)"
read ROOT
echo -e "\nCreando el sistema de archivos...\n"
mkfs.fat -F32 -n "EFISYSTEM" "${EFI}"
mkfs.ext4 -L "ROOT" "${ROOT}"

# Montando particiones.
echo -e "\nMontando las particiones...\n"
mount -t ext4 "${ROOT}" /mnt
mkdir /mnt/boot
mount -t vfat "${EFI}" /mnt/boot/

# Instalando el sistema base.
echo "Instalando el sistema base..."
read -n1 -rep "Te gustaria instalar los paquetes? (s/n)" pqts
if [[ $pqts =~ ^[Ss]$ ]]; then
    pacstrap /mnt base base-devel linux-zen linux-firmware intel-ucode nano   
else
    printf "El sistema base no sera instalado.\n"
fi

sleep 3
#Limpiar pantalla.
clear

# Creando archivo fstab.
echo ""
echo "Creando archivo fstab..."
sleep 3
genfstab -U /mnt > /mnt/etc/fstab
cat /mnt/etc/fstab
sleep 3

# Zona horaria.
echo "Configurando la zona horaria..."
arch-chroot /mnt /bin/bash -c "ln -sf /usr/share/zoneinfo/America/Hermosillo /etc/localtime"
arch-chroot /mnt /bin/bash -c "hwclock --systohc"
sleep 3
clear

# Idioma del sistema.
echo -e "\t\t\t| Idioma del Sistema |"
sed -i 's/^#es_MX.UTF-8 UTF-8/es_MX.UTF-8 UTF-8/' mnt/etc/locale.gen
#echo "es_MX.UTF-8 UTF-8" > /mnt/etc/locale.gen
arch-chroot /mnt /bin/bash -c "locale-gen" 
echo "LANG=es_MX.UTF-8" > /mnt/etc/locale.conf
cat /mnt/etc/locale.gen
echo ""
cat /mnt/etc/locale.conf
sleep 4
clear

# Establecer distribucion del teclado.
echo "KEYMAP=us" > /mnt/etc/vconsole.conf 
cat /mnt/etc/vconsole.conf
sleep 4
clear

#Agregando el hostname.
read -p "Cual seria el hostname? " hostname
echo "$hostname" > /mnt/etc/hostname
cat /mnt/etc/hostname
sleep 4
clear

echo "Configurando el localdomain..."
cat <<EOF > mnt/etc/hosts
127.0.0.1	localhost
::1			localhost
127.0.1.1	$hostname.localdomain	$hostname
EOF
#echo -e "127.0.0.1   localhost\n::1   localhost\n127.0.1.1   $hostname.localdomain   $hostname" > /mnt/etc/hosts
cat /mnt/etc/hosts
sleep 4

#Configurar el password para root.
echo "Configurando el password para root..."
arch-chroot /mnt /bin/bash -c "passwd"
sleep 4
clear


read -n1 -rep "Te gustaria instalar paquetes necesarios para los dispositivos? (s/n)" maspaquetes
if [[ $maspaquetes =~ ^[Ss]$ ]]; then
    for paquete in efibootmgr networkmanager wireless_tools wpa_supplicant dialog mtools dosfstools ntfs-3g xdg-user-dirs bluez bluez-utils openssh htop wget iwd smartmontools xdg-utils git; do
        arch-chroot /mnt /bin/bash -c "pacman -S --noconfirm $paquete"
        if [ $? -ne 0 ]; then
            echo -e "$paquete instalacion ha fallado, por favor revisa el archivo: install.log"
            exit 1
    	fi
    done	
else
  printf "Los paquetes no seran instalados.\n"
fi

sleep 4
clear

read -n1 -rep "Te gustaria instalar el controlador de audio pipewire? (s/n)" audio
if [[ $audio =~ ^[Ss]$ ]]; then
    for controler in pipewire pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire libpulse wireplumber; do
        arch-chroot /mnt /bin/bash -c "pacman -S --noconfirm $controler"
        if [ $? -ne 0 ]; then
            echo -e "$controler instalacion ha fallado, por favor revisa el archivo: install.log"
            exit 1
    	fi
    done	
else
  printf "Pipewire no sera instalado.\n"
fi

sleep 4
clear

#Habilitando servicio necesario para discos SSD.
echo "Habilitando servicio necesario para discos SSD..."
arch-chroot /mnt /bin/bash -c "systemctl enable fstrim.timer"

echo "Habilitando el servicio NetworkManager..."
arch-chroot /mnt /bin/bash -c "systemctl enable NetworkManager"

echo "Habilitando el servicio bluetooth..."
arch-chroot /mnt /bin/bash -c "systemctl enable bluetooth"

#echo "Habilitando el servicio archlinux keyring..."
#arch-chroot /mnt /bin/bash -c "systemctl enable archlinux-keyring-wkd-sync.timer"

#Creacion de Usuario.
read -p "Ingrese el nombre de usuario nuevo:" usuario
arch-chroot /mnt /bin/bash -c "useradd -mG wheel,storage,audio $usuario"
sleep 4
clear
echo "Escriba su contraseña nueva..."
#read -p "Ingrese la contraseña nueva para $usuario:" upasswd
#arch-chroot /mnt /bin/bash -c "echo $usuario:$upasswd | chpasswd"
arch-chroot /mnt /bin/bash -c "passwd $usuario"
clear

#Permisos de super usuario al grupo wheel.
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' mnt/etc/sudoers
#sed -i 's/# %wheel/%wheel/' /mnt/etc/sudoers
cat /mnt/etc/sudoers
sleep 4
clear

#Habilitando repositorio multilib.
sed -i 's/^# [multilib]/[multilib]/' /mnt/etc/pacman.conf
#sed -i 's/#Include/Include/g' /mnt/etc/pacman.conf
cat /mnt/etc/pacman.conf
sleep 4
clear

echo "Instalando el boot loader..."
arch-chroot /mnt /bin/bash -c "bootctl --path=/boot install"
sleep 4
clear

echo "Editando el archivo loader.conf..."
echo -e "default arch-*\ntimeout 0\n#console-mode keep" > /mnt/boot/loader/loader.conf
cat /mnt/boot/loader/loader.conf
sleep 4

echo "Creando el archivo arch.conf..."
echo -e "title Arch Linux\nlinux /vmlinuz-linux-zen\ninitrd /intel-ucode.img\ninitrd /initramfs-linux-zen.img\noptions root=/dev/nvme0n1p6 rw" > /mnt/boot/loader/entries/arch.conf
cat /mnt/boot/loader/entries/arch.conf
sleep 4
clear

#SUBSCRIPT
cat <<REALEND > /mnt/entorno.sh

OK="$(tput setaf 2)[OK]$(tput sgr0)"
ERROR="$(tput setaf 1)[ERROR]$(tput sgr0)"
NOTE="$(tput setaf 3)[NOTE]$(tput sgr0)"
WARN="$(tput setaf 166)[WARN]$(tput sgr0)"
CAT="$(tput setaf 6)[ACTION]$(tput sgr0)"
ORANGE=$(tput setaf 166)
YELLOW=$(tput setaf 3)
RESET=$(tput sgr0)
GREN='\033[0;32m'

LOG="install-$(date +%d-%H%M%S).log"

# Imprimir mensaje de advertencia de contraseña.
printf "\n${YELLOW} Algunos comandos requieren que ingrese su contraseña para poder ejecutarse.\n"
printf "Si le preocupa ingresar su contraseña, puede cancelar el script y revisar el contenido de este script.${RESET}\n"
sleep 2
printf "\n"

# Continuar con la instalacion.
read -n1 -rep "${CAT} ¿Desea continuar con la instalación? (S/N) " CONTINU
    echo
if [[ $CONTINU =~ ^[Ss]$ ]]; then
    printf "\n%s  Iniciando la instalación...\n" "${OK}"
else
    printf "\n%s  No se realizaron cambios en tu sistema.\n" "${NOTE}"
    exit
fi

#clear screen
clear

#----------------------------------------------------------#
# Buscar el ayudante de AUR e instálar si no se encuentra. #
#----------------------------------------------------------#

printf "\n%s - Se necesita el programa Yay para instalar algunos paquetes desde AUR. Verificando si se encuentra instalado...\n" "${NOTE}"
sleep 2
ISAUR=$(command -v yay)

if [ -n "$ISAUR" ]; then
    printf "\n%s - El programa Yay ya está instalado. Continuando con la ejecución del script...\n" "${OK}"
    sleep 2
else 
    printf "\n%s - El programa Yay no se encuentra instalado.\n" "$WARN"
    printf "\n%s - Instalando yay desde AUR...\n" "${NOTE}"
                git clone https://aur.archlinux.org/yay-bin.git || { printf "%s - Error al clonar yay desde AUR.\n" "${ERROR}"; exit 1; }
                cd yay-bin || { printf "%s - Error al ingresar al directorio yay-bin.\n" "${ERROR}"; exit 1; }
                makepkg -si --noconfirm 2>&1 | tee -a "$LOG" || { printf "%s - Error al instalar yay desde AUR.\n" "${ERROR}"; exit 1; }
                cd ..
fi

# Limpiar pantalla.
clear

#------------------------#
# Actualizar el sistema. #
#------------------------#

printf "\n%s - Realizando una actualización completa del sistema para evitar problemas...\n" "${NOTE}"
sleep 2
ISAUR=$(command -v yay)

$ISAUR -Syu --noconfirm 2>&1 | tee -a "$LOG" || { printf "%s - No se pudo actualizar el sistema.\n" "${ERROR}"; exit 1; }

# Limpiar pantalla.
clear

#---------------------------------------------------#
# Configurar el script para salir en caso de error. #
#---------------------------------------------------#

set -e

#---------------------------------#
# Función para instalar paquetes. #
#---------------------------------#
install_package() {
    # Comprobando si el paquete ya está instalado.
    if $ISAUR -Q "$1" &>> /dev/null ; then
        echo -e "${OK} $1 Ya está instalado, saltando..."
    else
        # Paquete no instalado.
        echo -e "${NOTE} Instalando $1 ..."
        $ISAUR -S --noconfirm "$1" 2>&1 | tee -a "$LOG"
        # Asegurarse de que el paquete esté instalado.
        if $ISAUR -Q "$1" &>> /dev/null ; then
            echo -e "\e[1A\e[K${OK} $1 Fue instalado."
        else
            # Falta algo, saliendo para revisar el registro.
            echo -e "\e[1A\e[K${ERROR} $1 No se pudo instalar, verifique install.log. ¡Es posible que deba instalarlo manualmente!"
            exit 1
        fi
    fi
}

# Función para imprimir mensajes de error.
print_error() {
    printf " %s%s\n" "${ERROR}" "$1" "$NC" 2>&1 | tee -a "$LOG"
}

# Función para imprimir mensajes de éxito.
print_success() {
    printf "%s%s%s\n" "${OK}" "$1" "$NC" 2>&1 | tee -a "$LOG"
}

# Salir inmediatamente si un comando sale con un estado distinto de cero.
set -e

#---------------------------------------------------#
# Instalar driver y paquetes adicionales de nvidia. #
#---------------------------------------------------#

echo "-------------------------------------------------"
echo "      INSTALACION DEL CONTROLADOR DE VIDEO       "
echo "-------------------------------------------------"

printf "\n${NOTE} Tenga en cuenta nvidia-dkms solo es compatible con la serie GTX 900 y posteriores. Si ya tiene instalados los controladores nvidia, tal vez sea conveniente elegir no instalar.\n"  
read -n1 -rp "${CAT} ¿Le gustaría instalar el controlador nvidia-dkms, nvidia-settings y nvidia-utils y todos los demás paquetes de nvidia? (s/n) " nvidia_driver
echo
if [[ $nvidia_driver =~ ^[Ss]$ ]]; then
	printf "${YELLOW} Instalando paquetes de Nvidia...\n"
    for krnl in $(cat /usr/lib/modules/*/pkgbase); do
        for NVIDIA in "${krnl}-headers" nvidia-dkms nvidia-settings nvidia-utils libva libva-nvidia-driver-git; do
            install_package "$NVIDIA" 2>&1 | tee -a $LOG
        done
    done
else
    printf "${NOTE} ¡No se instalaran paquetes de nvidia!\n"
fi

# Verificar si los módulos nvidia ya están agregados en mkinitcpio.conf y agregue si no.
if grep -qE '^MODULES=.*nvidia. *nvidia_modeset.*nvidia_uvm.*nvidia_drm' /etc/mkinitcpio.conf; then
	echo "Módulos de Nvidia ya incluidos en /etc/mkinitcpio.conf" 2>&1 | tee -a $LOG
else
	sed -Ei 's/^(MODULES=\([^\)]*)\)/\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf 2>&1 | tee -a $LOG
	echo "Módulos Nvidia agregados en /etc/mkinitcpio.conf"
fi
sudo mkinitcpio -P 2>&1 | tee -a $LOG
printf "\n"   

# Preparando exec.conf para habilitar env = WLR_NO_HARDWARE_CURSORS,1 para que esté listo una vez que se copien los archivos de configuración.
#sed -i '14s/#//' config/hypr/configs/ENVariables.conf
    
# Pasos adicionales de Nvidia.
NVEA="/etc/modprobe.d/nvidia.conf"
if [ -f "$NVEA" ]; then
    printf "${OK} Parece que nvidia-drm modeset=1 ya está agregado en su sistema.\n"
    printf "\n"
else
    printf "\n"
    printf "${YELLOW} Agregando opciones a $NVEA..."
    sudo echo -e "options nvidia-drm modeset=1" | sudo tee -a /etc/modprobe.d/nvidia.conf 2>&1 | tee -a $LOG
    printf "\n"  
fi
    
# Lista negra nouveau.
read -n1 -rep "${CAT} ¿Le gustaría incluir a nouveau en la lista negra? (s/n)" lnegra
echo
if [[ $lnegra =~ ^[Ss]$ ]]; then
    NOUVEAU="/etc/modprobe.d/nouveau.conf"
    if [ -f "$NOUVEAU" ]; then
        	printf "${OK} Parece que nouveau ya está en la lista negra.\n"
    else
        printf "\n"
        echo "blacklist nouveau" | sudo tee -a "$NOUVEAU" 2>&1 | tee -a $LOG 
        printf "${NOTE} Ha sido agregado a $NOUVEAU.\n"
        printf "\n"          

        if [ -f "/etc/modprobe.d/blacklist.conf" ]; then
            echo "install nouveau /bin/true" | sudo tee -a "/etc/modprobe.d/blacklist.conf" 2>&1 | tee -a $LOG 
        else
            echo "install nouveau /bin/true" | sudo tee "/etc/modprobe.d/blacklist.conf" 2>&1 | tee -a $LOG 
        fi
    fi
else
    printf "${NOTE} Saltarse la lista negra de nouveau.\n"
fi

# Limpiar pantalla.
clear

echo "-------------------------------------------------"
echo "     INSTALACION DEL ENTORNO DE ESCRITORIO       "
echo "-------------------------------------------------"

read -p "Introduce el numero correspondiente al entorno de escritorio deseado: " DESKTOP
echo "1. GNOME"
echo "2. KDE"
echo "3. XFCE"
echo "4. Hyprland"
echo "5. Sin entorno de Escritorio."

#Instalacion del Entorno de Escritorio.
if [[ $DESKTOP == '1' ]]
then 
    pacman -S gnome gdm --noconfirm
    systemctl enable gdm
elif [[ $DESKTOP == '2' ]]
then
    pacman -S plasma sddm kde-applications --noconfirm
    systemctl enable sddm
elif [[ $DESKTOP == '3' ]]
then
    pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter --noconfirm
    systemctl enable lightdm
elif [[ $DESKTOP == '4' ]]
then
    if ! lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq nvidia; then
        printf "${YELLOW} No se detectó GPU NVIDIA en su sistema. Instalando Hyprland sin el soporte de Nvidia..."
        sleep 1
        for HYP in hyprland; do
            install_package "$HYP" 2>&1 | tee -a $LOG
        done
    else
	    printf "${YELLOW} GPU NVIDIA detectada. Tenga en cuenta que nvidia-wayland sigue siendo inestable.\n"
	    read -n1 -rp "${CAT} ¿Te gustaría instalar Nvidia Hyprland? (s/n) " NVIDIA
	    echo
	    if [[ $NVIDIA =~ ^[Ss]$ ]]; then
    	    # Instalar Nvidia Hyprland
    	    printf "\n"
    	    printf "${YELLOW}Instalando Hyprland nvidia...${RESET}\n"
    	    if pacman -Qs hyprland > /dev/null; then
        	    read -n1 -rp "${CAT} Hyprland detectado. ¿Le gustaría eliminarlo e instalar hyprland-nvidia en su lugar? (s/n) " nvidia_hypr
        	    echo
        	    if [[ $nvidia_hypr =~ ^[Ss]$ ]]; then
    		        for hyprnvi in hyprland hyprland-nvidia-git hyprland-nvidia-hidpi-git; do
        	            sudo pacman -R --noconfirm "$hyprnvi" 2>/dev/null | tee -a $LOG || true
    		        done
                fi
            fi
    	    install_package "hyprland-nvidia" 2>&1 | tee -a $LOG
	    else
   	 	    printf "${YELLOW} Instalando Hyprland sin compatibilidad con Nvidia...\n"
    	    for hyprnvi in hyprland-nvidia-git hyprland-nvidia hyprland-nvidia-hidpi-git; do
        	    sudo pacman -R --noconfirm "$hyprnvi" 2>/dev/null | tee -a $LOG || true
    	    done
    	    for HYP2 in hyprland; do
                install_package "$HYP2" 2>&1 | tee -a $LOG
    	    done
	    fi
    fi

    # Limpiar pantalla.
    clear 

    # Instalación de otros componentes necesarios.
    printf "\n%s - Instalando otros componentes necesarios...\n" "${NOTE}"
    sleep 2

    for PKG1 in foot swaylock-effects wofi dunst wl-clipboard cliphist polkit-gnome nwg-look-bin python-requests playerctl qt5ct; do
        install_package "$PKG1" 2>&1 | tee -a "$LOG"
        if [ $? -ne 0 ]; then
            echo -e "\e[1A\e[K${ERROR} - $PKG1 la instalación ha fallado, verifique install.log"
            exit 1
        fi
    done

    for PKG2 in thunar thunar-volman tumbler thunar-archive-plugin mousepad btop jq gvfs gvfs-mtp ffmpegthumbs mpv pamixer brightnessctl viewnior pavucontrol; do
        install_package  "$PKG2" 2>&1 | tee -a "$LOG"
        if [ $? -ne 0 ]; then
            echo -e "\e[1A\e[K${ERROR} - $PKG2 la instalación ha fallado, verifique install.log"
            exit 1
        fi
    done

    for FONT in otf-font-awesome ttf-jetbrains-mono-nerd ttf-jetbrains-mono otf-font-awesome-4 ttf-droid ttf-fantasque-sans-mono adobe-source-code-pro-fonts; do
        install_package  "$FONT" 2>&1 | tee -a "$LOG"
        if [ $? -ne 0 ]; then
            echo -e "\e[1A\e[K${ERROR} - $FONT la instalación ha fallado, verifique install.log"
            exit 1
        fi
    done
else
    echo "Tienes que escoger un numero..."
fi

REALEND

arch-chroot /mnt sh entorno.sh

#Fin del script.
read -n1 -rep "Te gustaria reiniciar el sistema? (s/n)" rboot
if [[ $rboot =~ ^[Ss]$ ]]; then
    umount -R /mnt
    reboot
else
    echo "Saliendo del script..."
    exit
fi
