#!/bin/sh -x
set -e
echo "* CONFIGURAR THEME PARA ZSH"
if (!(sed -i -e "s/robbyrusell/maran/" ~/.zshrc));then
    echo "* NO SE PUDO CAMBIAR THEME A ZSH"
fi
source ~/.zshrc
