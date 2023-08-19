#!/bin/bash

#Limpiar pantalla.
clear

echo ""
echo "         #####################################################"
echo "         #                     BIENVENIDO!                   #"
echo "         #####################################################"
echo ""
printf "\n"

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
clear

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
echo "es_MX.UTF-8 UTF-8" > /mnt/etc/locale.gen
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
echo -e "127.0.0.1   localhost\n::1   localhost\n127.0.1.1   $hostname.localdomain   $hostname" > /mnt/etc/hosts
cat /mnt/etc/hosts
sleep 4

#Configurar el password para root.
echo "Configurando el password para root..."
arch-chroot /mnt /bin/bash -c "passwd"
sleep 4
clear


read -n1 -rep "Te gustaria instalar paquetes necesarios para los dispositivos? (s/n)" maspaquetes
if [[ $maspaquetes =~ ^[Ss]$ ]]; then
    for paquete in efibootmgr networkmanager wireless_tools wpa_supplicant dialog mtools dosfstools ntfs-3g xdg-user-dirs openssh htop wget iwd smartmontools xdg-utils git; do
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
    for controler in pipewire pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire libpulse; do
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

#echo "Habilitando el servicio archlinux keyring..."
#arch-chroot /mnt /bin/bash -c "systemctl enable archlinux-keyring-wkd-sync.timer"

#Creacion de Usuario.
read -p "Ingrese el nombre de usuario nuevo:" usuario
arch-chroot /mnt /bin/bash -c "useradd -mG wheel $usuario"
sleep 4
clear
echo "Escriba su contraseña nueva..."
#read -p "Ingrese la contraseña nueva para $usuario:" upasswd
#arch-chroot /mnt /bin/bash -c "echo $usuario:$upasswd | chpasswd"
arch-chroot /mnt /bin/bash -c "passwd $usuario"
clear

#Permisos de super usuario al grupo wheel.
#sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' mnt/etc/sudoers
#sed -i 's/# %wheel/%wheel/' /mnt/etc/sudoers
#cat /mnt/etc/sudoers
#sleep 4
#clear

#Habilitando repositorio multilib.
#sed -i 's/^# [multilib]/[multilib]/' /mnt/etc/pacman.conf
#sed -i 's/#Include/Include/g' /mnt/etc/pacman.conf
#cat /mnt/etc/pacman.conf
#sleep 4
#clear

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

#Fin del script.
echo "Instalación completa.\n"
read -n1 -rep "Le gustaria reiniciar el sistema? (s/n)" rboot
if [[ $rboot =~ ^[Ss]$ ]]; then
    umount -R /mnt
    reboot
else
    echo "Saliendo del script..."
    exit
fi
